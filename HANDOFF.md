# Handoff — faah.me

State of the Miso port after the 2026-09-11 work session, the 2026-09-12
follow-up audit, and the subsequent full-codebase review. Written for the next agent or contributor: what exists, what
was verified, what is still open. The migration record lives in
`.bb/MIGRATION.md`; architecture notes live in `.bb/AGENTS.md` (gitignored —
see Open items).

- Repository: `~/dev/site` (`git@github.com:fahmiirsyadk/site.git`)
- Last commit checked: `a3b3eec` (`Narrow the content column to one measure`).
  `HANDOFF.md` already had uncommitted edits before the full review; the review
  made no tracked code changes. Section 7 records unresolved findings.
- Package: `site-miso`, targets WASM in the browser, native for tests and
  prerender
- Tests: `make test` green (native `runEffect`/pure specs in `test/Spec.hs`)
- Output: `make all` builds and prerenders 7 catalog pages + `404.html`,
  `sitemap.xml`, `robots.txt` into `public/`

## What shipped in this workstream

### 1. Prerender pipeline and cache busting (commit 83ac81c and before)

- `prerender/Main.hs` renders every route from `Site.Meta.prerenderRoutes`
  through `Site.Document.documentView` with `Miso.Html.Render.toHtml`, then
  writes `public/<path>/index.html`, `404.html`, `sitemap.xml`, `robots.txt`.
- `cabal.project` enables miso's `ssr` flag only for non-WASM/non-JS
  architectures; the browser builds get real DOM nodes instead.
- Static assets are cache-busted with `?v=<FNV-1a of public/app.wasm>`,
  stamped by prerender after `make optim`. `static/index.js` reads the query
  string from its own URL and appends the same stamp to `ghc_wasm_jsffi.js`
  and `app.wasm`, keeping one deploy's loader, glue, and WASM together.
- `make all` = `update → build → optim → prerender`; `optim` must precede
  `prerender` because the hash covers the optimized WASM.

### 2. Dithered-image UX and off-screen cost

- CSS pre-dither placeholder (grayscale + ink bayer screen, gated by the
  pre-paint `js` class) and a 300ms crossfade; the source image stays visible
  until `data-dither-ready`, and WebGL failure raises `data-dither-fallback`.
- A root's WebGL instance is mounted one screen before it can be seen. The
  page scrolls inside `#content-scroll`, whose `overflow` clips targets, so
  IntersectionObserver margins cannot pre-mount; a capture-phase scroll
  listener (`mountNearby`) does it and the observer is pause-only.
- A root mounted while already off screen is paused at mount time (the
  observer only reports changes).
- Measured A/B against the previous build (headless Firefox, post page,
  3 runs each): mount lead 0px on every root before vs 350–2100px after;
  off-screen dither draws 78–83/s → 0/s at the page bottom and ~80/s → ~16/s
  after scrolling back to the top. Startup and frame pacing unchanged
  (cover-ready medians ~1.6–1.9s; 17.08ms median frame time).

### 3. Idiom and contracts pass

- `Site.Config` now owns the DOM contract: `routeMotionKey`, post-prose
  class/selector/heading selector, hollow class/selector/dragging key,
  scribble keys/selectors, lab-interaction key and values, dithered-image
  keys/selectors/state keys, internal-link key/selector/guard property, and
  `darkClassName`/`prefersDarkQuery`. Views, `Prose`, and all widgets consume
  them; no raw contract strings remain in `src/`.
- `Site.Model.labInteractionName` uses `Route.activeSection` + `Config`
  instead of a private `activeSection` with a hardcoded `"lab"`.
- `Site.Widgets.Gl` is the shared widget helper: `(>>>=)`, `number`, `int`,
  `performanceNow`, and `mountWithRetry` (the 40 × 500ms context retry, once
  duplicated in Sea and Hollow); `isAbsent` lives in `Site.Platform` and is
  re-exported. Local copies in Dither/Hollow/Sea/Scroll/Scribble were removed.
- Actions named for occurrences: `SyncTheme → AppMounted`,
  `SetReadingProgress → SelectedReadingProgress`,
  `MoveReadingProgress → AdjustedReadingProgress`,
  `ResetCopyStatus → CopyStatusExpired`.
- The anti-flash script in `Site.Document` is built from
  `Config.themeStorageKey`, `Config.darkClassName`, `Config.prefersDarkQuery`,
  and `Theme.storageName`, so it cannot drift from `Platform.applyTheme`.
  Tests assert the script uses each constant.

### 4. Development pipeline

- `make watch-preview` (new): watches `content/`, `shaders/`, `styles/`,
  `src/`, `app/`, `static/`, runs the real `make build` + `make prerender`,
  and serves `public/` on 8080. CSS edits take a fast path (Tailwind + copy,
  ~1s); a real content edit is ~31s; a view edit ~10s.
- `scripts/watch-preview.mjs` keeps its `FSWatcher` handles referenced — an
  unreferenced watcher was collected and silently stopped reporting.
- The Makefile runs everything through Nix: `NODE_RUN` wraps Node/npm targets
  in the wasm shell, native phases (`NATIVE_CABAL`, `NATIVE_RUNGHC`) always
  cross into the default shell. The host needs only `nix`.
- `npm ci` is a one-time step, run as
  `nix develop .#wasm --command npm ci`.
- Reference comparison: `haskell-miso/haskell-miso.org` (`new-site`) is the
  closest analogue and matches our `all/build/optim/prerender` order and hash
  rationale. It has no prod-mode watcher; `watch-preview` goes beyond it.
  Its no-`-finteractive` watch strategy was considered and deliberately not
  adopted (see Open items).

### 5. Repository hygiene

- `generated/` is untracked and gitignored again (the generators run before
  every build); `public/` is ignored; `package-lock.json` is tracked.
- `README.md` restored with layout, build commands, and first-run steps.
- `.bb/MIGRATION.md` gained a status block closing phases 0–6 and recording
  phase-7 outcomes (loops stay in Haskell; vitest not ported; sizes; the
  visual-parity baseline caveat).
- `.bb/skills/` (the Miso skills suite) and `.bb/MIGRATION.md` are tracked.
- The old duplicate workspace `~/dev/site-miso` was deleted after verifying
  the trees identical.

### 6. Follow-up audit (2026-09-12)

An idiom and correctness review of the ported code, with fixes:

- **Async work carries identity.** `Site.Model` now has a `Navigation` sum type
  (`Settled | LeavingFor | AwaitingURI | EnteringPage`) instead of the
  motion/pending/version trio, and post chrome (`PostState`) lives inside
  `PostPage`. Copy-link completions and expiry timers carry a `PostRequest`
  (post generation + copy version), and reading measurements carry the post
  generation, so results from a previous post or an earlier request are
  ignored instead of overwriting the current page's state.
- **Widget lifetime is explicit.** `Site.Widgets.Runtime` owns one
  `Browser.Mount` per single-instance widget and the dither `Registry`;
  `Site.App` threads it to `Site.Update`. `Browser.Mount` compares elements by
  identity, serializes duplicate hydration hooks, and owns the context retry
  and its cancellation. `Browser.Scope` is the idempotent, LIFO cleanup
  registry used by every widget (listeners, observers, buffers, programs,
  contexts). The `Element` newtype in `Site.Action` carries DOM identity into
  lifecycle actions and keeps `Show` usable.
- **One frame-scheduling policy.** `Site.FrameLoop` owns
  continuous/on-demand scheduling and visibility cancellation; Sea, Hollow,
  and Dither use it, and reduced motion is genuinely one frame per change.
  Hollow's drag and hover snap under reduced motion instead of interpolating.
- **Typed content.** `Site.Section.Section` and `PublicationStatus` replace
  the section/status strings in routes and posts; the content generator
  validates frontmatter and fails the build on an unknown value.
- **Single-sourced palette.** The five shared colors are Tailwind `@theme`
  tokens (`--color-paper/ink/coral/coral-bright/coral-deep/hairline`); views
  use the generated utilities, plain CSS reads the variables, and
  `--dither-ink` points at `--color-coral`.
- **Smaller fixes.** Media classification in `Site.View.Post` strips query and
  fragment before deciding MP4/GIF, matching the generator; the unread
  `data-relative-date` attributes were removed; the leave-duration test now
  parses the actual CSS rule instead of comparing against a literal.
- **The runtime crash fixed mid-review.** The first cut passed a null target
   to the dither registry's `IntersectionObserver`; `Browser.observe` now takes
   `Maybe JSVal` and observes nothing until roots arrive. `sameNode` and
   `mountElement` tolerate absent refs.
- **Reading slider keyboard behavior.** The delegated `keydown` handler now
  leaves browser defaults enabled. A dedicated `Browser.Mount` in
  `Widgets.Runtime` uses `Browser.Scope.listen` to prevent default only for
  handled slider keys and to release the listener on teardown.
- **One scroll owner at every breakpoint.** The standard shell now constrains
  itself to the dynamic viewport at all widths, so `#content-scroll` remains
  the owner used by the scroll widget, route reset, captured scroll events, and
  dither visibility calculations on mobile as well as desktop.

### 7. Full-codebase review (2026-09-12, findings and subsequent fix)

Read `.bb/AGENTS.md` and the Miso thinking, components, effects, JavaScript,
routing/SSR, views, and toolchain skills and their relevant references. Reviewed
the MVU core, views, widget lifetime and scheduling, shaders, content generation,
prerendering, and build scripts. The architecture is sound: pure shared views,
typed route/content vocabularies, versioned async results, and explicit widget
ownership should be retained. The main gaps are integration contracts and
failure-path coverage.

**R1 and R2 were fixed after this review; R3–R9 remain open.** Browser testing was
explicitly skipped at the user's request. Source-level findings below are not
browser reproductions. Line references describe the reviewed tree.

| ID | Priority | Finding and next action | Evidence |
| --- | --- | --- | --- |
| R1 | Fixed (P1) | **Reading slider traps focus.** `src/Site/View/Post.hs` previously prevented the default for every `keydown`, including Tab/Shift+Tab, before unsupported keys became `IgnoredKey`. The handler now uses default options; `src/Site/Widgets/Runtime.hs` owns a scoped target listener that prevents default only for handled slider keys. | Source-level fix; `make test` passed; no browser test. |
| R2 | Fixed (P2) | **Mobile scroll ownership was inconsistent.** `src/Site/View.hs` constrained the shell only at `md`, while `Widgets/Scroll.hs`, `Platform.hs`, and `Widgets/Dither.hs` used `#content-scroll` at every width. The standard shell now uses `h-dvh max-h-dvh overflow-hidden` at every breakpoint, with `#content-scroll` as its constrained flex child, so the existing consumers share one scroll owner. | Source-level layout analysis; `npm run build:css`, `make test`, and `make build` passed; no browser test. |
| R3 | P2 | **Markdown titles break generated Haskell.** `scripts/content/generate.mjs:357–372` emits bare `Just "title"` inside `Link`/`Image`/`PlainImage`/`Video` constructor applications. Emit `(Just "title")`. | Isolated titled-link/image fixture generated successfully, then failed GHC typechecking with constructor-arity/type errors. |
| R4 | P2 | **Initially visible dither images never start their loop.** `Widgets/Dither.hs:494–501` starts `dsVisible=True`, while `FrameLoop.hs:33–51` starts hidden. `Dither.setVisible` at lines 277–286 skips propagation when the value is unchanged. The immediate first draw masks the missing animation until an offscreen/onscreen transition. Align initialization or always propagate visibility. | Native fake-driver probe: zero requests on the initial invalidate path, one after explicit `setVisible True`; no browser test. |
| R5 | P2 | **SPA navigation leaves stale document metadata.** `Update.hs:92–108` swaps the body without updating the title, canonical, or description; `Document.hs:56–89` writes these only during prerender. Add a route-commit platform effect using `Site.Meta`. | Source-level inspection of route updates and metadata consumers. |
| R6 | P2 | **CSS-only/loader-only deploys reuse the asset stamp.** `prerender/Main.hs:56–74` hashes only WASM when present, but versions CSS and the loader with that hash too. Hash all covered assets or use per-asset hashes. Resolve before enabling immutable asset caching. | Source-level build analysis; stale delivery depends on host cache headers. |
| R7 | P2 | **Section rows cannot shrink on narrow screens.** `View/Section.hs:38–50` gives both title and date `shrink-0`, plus a minimum-width separator. The existing long Grok title exposes the constraint. Allow title wrapping/shrinking and hide or move the date on narrow screens, as the home list already does. | Source-level flex-layout analysis; visual overflow not browser-tested. |
| R8 | P2 | **Sea/Hollow cannot recover from context loss.** `Widgets/Sea.hs:237–243` and `Widgets/Hollow.hs:224–230` register no context-loss/restoration handlers. Their mount slots remain occupied with invalid resources after loss. Stop rendering on loss and rebuild scoped resources on restoration; Dither provides an existing lifecycle example. | Source-level lifecycle analysis; context loss not induced. |
| R9 | P3 | **Failed second copy leaves “Copied” stuck.** `Update.hs:200–219`: request 1 succeeds, request 2 starts and fails, request 1's expiry is rejected as stale, and no current timer clears the retained status. Reset status on a new request or handle the current failure explicitly. | Reproduced through the actual update function with `runEffect`; final state remained `Copied`. |

Recommended implementation order: **R3 → R4**, then metadata,
cache-versioning, responsive rows, context restoration, and copy failure state.
Add focused regression coverage for titled generated constructors and the
copy-failure sequence; verify widget visibility at the integration boundary,
not only the generic frame scheduler in isolation.

## How to run

| Task | Command | Notes |
| --- | --- | --- |
| First checkout | `nix develop .#wasm --command npm ci` | project-local `node_modules` |
| Live dev | `make watch-preview` | real build + prerender on change, :8080 |
| Full test | `make test` | native, no browser |
| Production build | `make all` | update + build + optim + prerender → `public/` |
| Rebuild, no network | `make build optim prerender` | skips `make update` |
| Serve the build | `make serve` | `http-server public -p 8080 -c-1` |
| GHCi hot reload | `make watch` | port 8080, caveats below; not with `watch-preview` |
| CSS only | `make css` / `make watch-css` | write `static/styles.css` |

Deploying: `public/` is a plain static site; configure the host to serve
`404.html` for unknown paths.

## Verified evidence

- `make test`: `all checks passed`, `Test suite spec: PASS` (fresh native
  build from the canonical tree).
- `make all`: builds WASM, `wasm-opt -all -O2` + `wasm-tools strip`
  (optimized binary 3,887,699 bytes), prerenders 8 pages.
- Browser contract check on the built output (headless Firefox): home
  scribble visible, sea `data-sea="ready"`, lab route
  `data-lab-interaction="hovered"`, post cover and first inline image
  `data-dither-initialized` + `data-dither-ready` with no fallback.
- Prerendered anti-flash script byte-identical to the pre-refactor output.
- Watcher: content edit rebuilt + rerendered and was visible in ~31s; CSS
  edit ~1s.
- 2026-09-12 follow-up (native and build checks on this tree):
  - `make test` green including new checks: `FrameLoop` coalescing,
    on-demand one-shot frames, visibility cancellation, and continuous
    self-rescheduling with a fake driver; palette tokens present and no raw
    palette hexes in the view modules; stale copy/scrape completions ignored;
    the leave duration read from the actual CSS rule.
  - `make build && make optim && make prerender` succeeds; optimized WASM
    3,944,807 bytes (hash `be1ec6182a087079`), all 8 pages carry the same
    `?v=` stamp, and the stamped hash equals the FNV-1a of `public/app.wasm`.
  - Prerendered pages contain the token utilities (`text-coral`,
    `bg-paper`, `text-ink`) and no `data-relative-date`.
  - NOT rerun after the follow-up: the headless-browser widget contract
    check. The last runtime error found (null `IntersectionObserver` target)
     was fixed and the bundle rebuilt. A later review explicitly skipped
     browser testing at the user's request; do not treat the earlier browser
     evidence as validation of the current tree.

### Latest review validation (2026-09-12)

- `make test`: passed (`all checks passed`, 1 suite passed). This runs native
  pure/update tests; scheduled browser effects are not executed.
- `nix develop .#wasm --command wasm32-wasi-cabal build exe:app`: succeeded,
  reported **Up to date**. This was not a fresh optimized/assembled build.
- `npm run build:css`: passed.
- Generated a separate titled-link/image Markdown fixture under
  `/tmp/opencode/site-review-fixture/`; native GHC rejected its generated
  module as described in R3. The repository's content was not modified.
- Ran `/tmp/opencode/site-review-state.hs` through native `cabal exec --
  runghc`: reproduced R9 and confirmed the frame-driver initialization
  mismatch underlying R4. These temporary probes are not repository tests
  and may not survive the session.
- A suspected preview-watcher self-trigger was investigated: an unchanged
  CSS build produced no `static/` watch events. An infinite rebuild loop was
  **not established** and is not an open finding.
- Browser tests: **skipped at the user's request**. No new hydration, visual,
  keyboard, mobile-layout, or WebGL-restoration runtime results.
- No new `make all`, optimization, or prerender run in this review; binary
  sizes and hashes above are historical measurements.
- Before this handoff update, `git status --short` showed only the existing
   `HANDOFF.md` modification. No tracked application code was changed.

### R1 follow-up validation (2026-09-12)

- `make test`: passed after moving the slider guard to `Browser.Mount` and
  `Browser.Scope.listen`.
- Browser testing: **skipped at the user's request**; keyboard focus behavior
  remains browser-unverified.

### R2 follow-up validation (2026-09-12)

- `npm run build:css`: passed and emitted the `h-dvh` and `max-h-dvh` utilities.
- `make test`: passed; `make build`: passed through WASM assembly and static
  asset generation.
- Browser testing: **not run**; mobile scroll ownership and dither visibility
  remain browser-unverified.

## Approved next architecture: native Haskell content compiler (2026-09-14)

**Status: implemented in the current working tree.** The content path now uses
a native Haskell compiler while preserving structured content and the shared
pure Miso renderer. The remaining fixture/parity work below is still open.

**Highlighter decision revised and approved:** retain highlight.js behind a small
build-time Node adapter. The earlier Skylighting proposal is superseded. Haskell
owns content compilation; replacing the working highlighter is not part of this
migration. Preserve current classed spans, language aliases, and highlighting CSS.

The planning review read the repository instructions, the Miso thinking, views,
routing/SSR, and toolchain skills and their relevant references, plus the content
generator, prose renderer/types, catalog queries, Cabal/Makefile integration, and
content tests. It also consulted upstream CommonMark and Skylighting documentation.
No implementation or build/browser validation was performed in that review.

### Current working-tree detail: R3

The old JavaScript Markdown generator has been removed. Titled constructors are
now emitted through Template Haskell expression construction, and the generated
module is compiled by both native tests and the WASM application build.

### Decision and end-to-end flow

```text
content/*.md
  -> native content compiler
       -> split/decode YAML frontmatter and validate metadata
       -> parse Markdown into a typed intermediate document
       -> normalize anchors, TOC, footnotes, and media
       -> batch code blocks through a Node/highlight.js JSON adapter
       -> validate returned structured text/span trees
       -> validate the complete catalog
       -> emit deterministic Haskell content modules
  -> generated/Site/Content/Generated.hs
  -> Site.Content (publication filtering, ordering, lookup, neighbours)
  -> Site.Prose (pure structured content -> Miso nodes)
       -> native prerender -> public/<route>/index.html
       -> browser WASM -> hydration and SPA navigation
```

Keep parsing and highlighting entirely at build time. Both targets consume the
same compiled content and view definitions. Retain ordinary Miso nodes for
images, videos, footnotes, and headings; do not replace prose with HTML injection
or introduce a stateful component for static content.

### Libraries selected

| Library | Responsibility | Dependency boundary |
| --- | --- | --- |
| `commonmark` | Markdown parser with custom typed output through `IsBlock`/`IsInline` adapters | Native compiler only |
| `commonmark-extensions` | Explicitly selected footnotes, pipe tables, smart punctuation, and bare-URL autolinks | Native compiler only |
| `yaml` + `aeson` | Decode frontmatter into a typed, validated record | Native compiler only |
| Existing `highlight.js` | Highlight code and return structured text/classed-span trees through a small Node adapter | Build-time Node only |
| `process` | Invoke the highlighting adapter once with a JSON batch | Native compiler only |
| `template-haskell` | Construct Haskell expression trees and pretty-print generated source | Native compiler only; no application splices |
| `text`, `containers`, `time` | Text, identifier/reference tracking, and date validation | Compiler; only lightweight dependencies needed by shared types cross into the app |
| Existing pinned Miso | Render shared prose to SSR HTML and browser nodes | Existing native/WASM application boundary |

Verify and pin compatible versions against the existing native Nix/Cabal
toolchain before implementation; no new dependency versions were tested here.
Select supported Markdown extensions explicitly rather than enabling a full
dialect whose constructs the renderer cannot represent.

References:

- https://github.com/jgm/commonmark-hs/tree/master/commonmark
- https://hackage.haskell.org/package/commonmark-extensions
- https://highlightjs.readthedocs.io/en/latest/api.html

### Module ownership and bootstrap boundary

Extract a small Cabal internal library, tentatively `content-core`:

```text
content-core/
  Site/Section.hs
  Site/Content/Types.hs
  Site/Prose/Types.hs
```

It owns `Section`, `PublicationStatus`, `Post`, `TocEntry`, `Block`, `Inline`,
`Footnote`, and the small semantic types needed for list starts and table
alignment. Retain the existing classed-span representation for highlighted code
rather than introducing new token categories. Use `Text` for content strings, converting
to `MisoString` at view/property boundaries and adapting existing consumers as
needed. Keep this library free of Miso, parser dependencies, IO, and imports of
generated content. Move definitions rather than maintaining duplicate types;
use re-exports where useful to preserve the existing application-facing API.

Add a native-only compiler executable, tentatively `content-compiler`:

```text
content-compiler/
  Main.hs
  Site/Content/Compiler/Frontmatter.hs
  Site/Content/Compiler/Markdown.hs
  Site/Content/Compiler/Normalize.hs
  Site/Content/Compiler/Highlight.hs
  Site/Content/Compiler/Emit.hs
```

- `Frontmatter`: metadata decoding, field/date validation, explicit defaults.
- `Markdown`: typed CommonMark output adapters and intermediate document.
- `Normalize`: heading/TOC/reference allocation, media classification, lowering
  to shared prose types. Retain source locations in the intermediate form where
  practical for file-specific errors; they need not ship in the final content.
- `Highlight`: collect code blocks, invoke the Node adapter, decode/validate its
  results, and attach shared highlighted-code data to the corresponding blocks.
- `Emit`: Haskell expression construction and deterministic file output.
- `Main`: file discovery, diagnostics, catalog validation, orchestration.

`src/Site/Prose.hs` remains the pure Miso renderer, importing the extracted types.
`Site.Content` continues to query the generated catalog. Existing post/document
views and the prerender executable continue using those interfaces.

**The compiler must not depend on the main `site-miso` library.** That library
imports `Site.Content.Generated`; depending on it would create a bootstrap cycle.
Both the compiler and application depend on `content-core`, and only the
application imports generated content. Mark the compiler unbuildable for
WASM/JavaScript targets, as with the native prerender target. Prove that a native
compiler build works with no generated content present.

### Semantics to implement deliberately

1. **Parse headings once; derive anchor and TOC together.** Use a normalization
   pass and a globally unique ID allocator. Preserve existing heading URLs for
   the current corpus, while handling collisions such as repeated `Foo` and a
   separate `Foo 2` heading.
2. **Allocate footnote references/backlinks consistently.** A heading used to
   build a TOC must not register its references a second time. Cover repeated
   references, including references in headings.
3. **Represent Markdown semantics currently lost.** Add ordered-list start
   numbers and table column alignment to the shared AST and renderer. Preserve
   tight/loose lists and existing heading-level behavior unless an intentional
   change is documented.
4. **Keep media rules compatible.** Preserve GIF, MP4, query/fragment stripping,
   `#no-dither`, alt text, optional titles, and the dither widget DOM contract.
5. **Retain highlight.js and existing classes.** Extract the current language
   registrations, aliases (`purescript` -> `haskell`, `toml` -> `ini`), and
   unknown/plain-language fallback into a small helper such as
   `scripts/content/highlight.mjs`. Use the public highlight.js API, not private
   emitter internals. Initially retain the existing HTML-to-text/span conversion
   inside this helper; no raw HTML crosses into the Haskell compiler or Miso.
   Invoke Node once per compiler run with all code blocks (skip when none), not
   once per block. Exchange JSON on stdin/stdout, with explicit block IDs and
   code/language requests; responses contain only text nodes and nested classed
   spans. Reserve stderr for diagnostics and propagate process/protocol failures
   as build errors. Validate response IDs, shape, and text preservation:
   concatenating a result's text leaves must equal its original code exactly,
   including Unicode, whitespace, and newlines. Keep language decisions in the
   helper as their single source. Verify Node availability through the existing
   Nix shell setup; do not assume it exists on the host or in the native shell.
6. **Validate metadata and catalog before emission.** Reject malformed fields,
   invalid dates, unknown sections/statuses, and duplicate `(section, slug)`
   routes with file-specific errors. Preserve intentional current defaults.
   Keep the existing explicit rejection of raw Markdown HTML.
7. **Emit source structurally.** Build constructor applications and literals as
   Haskell expressions and pretty-print them; do not port scattered JavaScript
   templates verbatim or treat derived `Show` as a source serialization format.
   Expression printing handles syntax, but generated-code compilation is still
   required to verify names, types, and imports.
8. **Make output deterministic.** Stable file ordering and safe generated
   binding names; write files only when content changes. Keep generated files
   gitignored. Real content edits will still require Haskell recompilation.

### Why this is better than the current compiler

| Current implementation | Planned replacement | Benefit |
| --- | --- | --- |
| JavaScript object shapes mirror Haskell constructors | Shared Haskell content vocabulary | Content shape changes are checked on both sides |
| Handwritten open/close-token walker | CommonMark with typed adapters | Less low-level traversal code to maintain |
| Line-based frontmatter; malformed arrays silently become `[]` | Typed YAML decoding and validation | Predictable quoting/lists/multiline fields and useful errors |
| Highlighting mixed into the full JavaScript content compiler | Isolated highlight.js adapter with a validated JSON contract | Preserves appearance and confines HTML/span conversion to one tested helper |
| Mutable TOC/reference bookkeeping inside parsing | Explicit normalization pass | One owner for IDs, TOC, and backlinks |
| Handwritten Haskell constructor strings | Haskell expression construction/printing | Structural parentheses and escaping |
| Ordered-list starts and table alignment discarded | Explicit AST fields | Better Markdown fidelity |
| Tests mostly inspect existing catalog values | Compiler fixtures and generated-code compilation | Edge cases checked before delivery |

The gain is maintainability and correctness, **not a measured runtime or build
speed improvement**. The current approach already keeps parsing/highlighting out
of WASM; preserve that. Costs include a larger native dependency graph, slower
first-time native builds, and migration work for Markdown semantics and the highlighting protocol;
some site-specific adapter and normalization code remains necessary.
Node stays for highlighting, Tailwind, and preview/build tooling. Haskell owns
content compilation and calls the narrow highlighting helper; highlight.js adds
no browser runtime cost because it remains build-time only. Keeping it avoids an
unnecessary syntax-token/CSS migration. Pandoc/Hakyll are not part of this chosen plan: the focused compiler
fits the existing Miso prerender/route pipeline without replacing the site builder.

### Execution order and acceptance gates

1. **Capture the baseline.** Re-read current diffs and relevant local Miso skills.
   Generate the five current posts using the existing emitter, retaining an
   isolated baseline of metadata, anchors, prose, and prerendered structure.
   Validate the existing R3 edit with titled-link/image fixtures. Do not use the
   live `faah.me` deployment as the Miso baseline.
2. **Extract the shared vocabulary.** Introduce `content-core`, adapt imports and
   `Text`/`MisoString` boundaries, and preserve current output with the old
   generator. Run appropriate native and WASM compilation checks before changing
   parser semantics.
3. **Build the native compiler alongside the old path.** Implement typed metadata,
   Markdown adapters, normalization, highlighting, and expression emission.
   Generate comparison output separately until parity checks pass. Verify the
   compiler bootstraps without the main application or generated modules.
4. **Add meaningful compiler fixtures.** Cover titled links and all media variants,
   quotes/backslashes/control characters/Unicode, malformed metadata, duplicate
   routes, heading collisions, repeated footnotes, nested tight/loose lists,
   non-1 ordered-list starts, aligned tables, raw-HTML rejection, highlighting
   text preservation, and unknown-language fallback. Compile generated fixture
   modules, not just compare source strings.
5. **Compare all five posts.** Preserve publication filtering, routes, metadata,
   existing heading URLs, TOC/footnote relationships, and widget markup. Inspect
   deliberate Markdown differences rather than blindly accepting new snapshots.
   Highlighted spans and existing CSS should remain compatible; investigate
   differences as regressions rather than adopting a new highlighting appearance.
6. **Switch build integration.** Run the compiler through the native Nix shell
   from `make content`. Preserve shader/geometry generation and the build ->
   optim -> prerender order. Update watcher inputs for `content-core/`,
   `content-compiler/`, and relevant build configuration; check both preview and
   GHCi watch paths. Include compiler tests in the normal test entry point.
   Verify parser/YAML/highlighting dependencies are absent from the WASM target.
7. **Remove the old content path after validation.** Remove the obsolete content
   generator and its unused Markdown npm dependencies, updating the lockfile;
   retain highlight.js, the new helper, and Node dependencies used by CSS, shaders,
   and preview tools. Update README, relevant
   architecture instructions, and this handoff to describe the implemented state.
8. **Final verification.** Run `make test` and `make build optim prerender`; check
   no-op generation does not rewrite output. Verify hard reload and SPA navigation
   on post routes, hydration diagnostics, footnote/TOC navigation, media widgets,
   and highlighted-code appearance in the browser. Report exact commands/results
   and any unperformed browser checks separately from source/build evidence.

The prior review's browser skip is historical; no new browser checks were run
while writing this plan. Other unresolved R4–R9 findings remain separate work and
must not be represented as fixed by this content migration.

### Current implementation checkpoint (2026-09-14)

- `content-core` and the native-only `content-compiler` are implemented.
- Markdown, YAML frontmatter, structured emission, catalog duplicate checks, and
  the build-time highlight.js JSON adapter are active in `make content`.
- The old `scripts/content/generate.mjs`, `markdown-it`, and
  `markdown-it-footnote` dependencies were removed.
- Compiler fixtures cover titled media, heading collisions, list starts, table
  alignment, raw HTML, invalid dates, and highlighted spans.
- `make test`, `make build`, `make optim`, `make prerender`, and deterministic
  no-op generation checks pass. Browser validation remains intentionally skipped.

## Open items (prioritized)

**The native content compiler workstream is implemented.** The unresolved R4–R9
review findings in section 7 still need attention, starting with dither startup.
This plan does not supersede their findings.
The following are the previously recorded follow-ups, retained for continuity:

1. **`make watch` (GHCi) is rougher than `watch-preview`.** `reload` clears
   `<head>` and `<body>` each cycle; the GHCi page is unstyled and the GHCi
   server only serves host files under `/fs/<absolute-path>`. The widget
   runtime now lives in `Main.main`, so `:main` gives each reload a fresh one,
   but whether every old mount is released before the new runtime attaches is
   untested under GHCi. Also, passing `-finteractive` flips cabal flags and
   invalidates the `make build` cache both ways. The reference site avoids all
   of this by always calling `misoWithContext`; that approach must be tested
   against the widgets before adopting.
2. **Visual parity gate (MIGRATION phase 7) has no clean baseline.**
   `faah.me` still serves the pre-PureScript generation, and the PureScript
   app at `2f3bd54` was a Vite dev entry. If the pass is still wanted, build
   `2f3bd54` in a worktree and diff that. The prebuilt `output/`, `.spago/`,
   and `.purs-ts/` directories in this checkout support it.
3. **Deployment is not configured.** CI was intentionally skipped. The site
   needs a host (any static server), an asset caching policy (fix R6 before
   making `?v=`-stamped assets immutable), compression (the WASM is ~3.9MB uncompressed), and the `404.html`
   fallback. `faah.me` does not serve this build yet.
4. **`.bb/AGENTS.md` is gitignored** by the existing `AGENTS.md` rule, so a
   fresh clone has no agent instructions. Add `!.bb/AGENTS.md` to
   `.gitignore` if it should be tracked.
5. Minor: `make build-js` does not run `make prerender` afterwards (the
   reference does, which completes the `?v=index.js` stamp); if miso itself
   needs patching, add a `cabal.project.dev`-style project file as the
   reference site does.

## Key files

| Path | Role |
| --- | --- |
| `src/Site/App.hs`, `Update.hs`, `Model.hs`, `Action.hs` | MVU core; effects are scheduled here, never in views |
| `src/Site/Config.hs`, `src/Site/Section.hs` | site constants and DOM contract, plus the section vocabulary |
| `src/Site/Platform.hs` | the only module besides widgets that touches the DOM/storage/clock |
| `src/Site/Document.hs`, `prerender/Main.hs` | head/document builder and the static generator |
| `src/Site/FrameLoop.hs` | browser-free frame scheduling policy (continuous/on-demand) |
| `src/Site/Widgets/Runtime.hs`, `Browser.hs` | explicit widget ownership: mounts, scopes, listeners, observers |
| `src/Site/Widgets/*.hs` | Sea, Hollow, Scribble, Dither, Scroll, Gl |
| `scripts/watch-preview.mjs` | production-parity dev loop |
| `Makefile` | Nix-only pipeline: `all`, `build`, `optim`, `prerender`, `test`, `watch`, `watch-preview`, `serve` |
| `test/Spec.hs` | native specs: routes, update transitions, content, and every widget's pure half |

## Gotchas

- The opencode thread that produced this report had `~/dev/site-miso` as its
  default working directory and that directory was deleted at the end; pass
  `~/dev/site` explicitly or point the environment there.
- `make` targets print a `Git tree ... is dirty` warning from Nix; harmless.
- Run `make watch` and `make watch-preview` one at a time — both bind 8080.
- `IntersectionObserver.observe` takes one element, never a spread list, and
  throws on `null`. `Browser.observe` therefore takes `Maybe JSVal`; pass
  `Nothing` only when the observer will receive targets later (the dither
  registry does exactly that).
- A callback handle is freed only after its listener is removed or its
  observer is disconnected. `Browser.Scope` enforces that order, so add new
  browser resources through it rather than with raw `syncCallback1`.
- Actions carrying DOM identity use the `Element` newtype; do not put a raw
  `JSVal` in an action that derives `Show` (the model and action types are
  logged).
