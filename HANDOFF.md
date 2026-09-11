# Handoff — faah.me

State of the Miso port after the 2026-09-11 work session. Written for the next
agent or contributor: what exists, what was verified, what is still open.
The migration record lives in `.bb/MIGRATION.md`; architecture notes live in
`.bb/AGENTS.md` (gitignored — see Open items).

- Repository: `~/dev/site` (`git@github.com:fahmiirsyadk/site.git`)
- Last code commit: `f8669ca` on `main`, pushed; working tree clean
- Package: `site-miso`, targets WASM in the browser, native for tests and
  prerender
- Tests: `make test` green (native `runEffect`/pure specs in `test/Spec.hs`)
- Output: `make all` builds and prerenders 8 pages + `404.html`,
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

## Open items (prioritized)

1. **Palette is not single-sourced.** `#FF4B26`, `#FF6B4A`, `#171717`,
   `#E5E5E5`, `#F5F5F5` appear as Tailwind arbitrary classes in four view
   modules, duplicated by `--dither-ink` in `styles/input.css` and
   `Dither.fallbackColor`. Recommended: Tailwind 4 `@theme` color tokens plus
   `--dither-ink: var(--color-…)`, verified with a generated-class-list diff.
2. **`make watch` (GHCi) is rougher than `watch-preview`.** `reload` clears
   `<head>` and `<body>` each cycle; the GHCi page is unstyled and the GHCi
   server only serves host files under `/fs/<absolute-path>`. Sea/Hollow/
   Scribble keep top-level refs in modules that GHCi does not recompile, so
   after a hot reload the new canvases may not re-attach (Dither self-heals
   via its body observer). Also, passing `-finteractive` flips cabal flags and
   invalidates the `make build` cache both ways. The reference site avoids all
   of this by always calling `misoWithContext`; that approach must be tested
   against the widgets before adopting.
3. **Visual parity gate (MIGRATION phase 7) has no clean baseline.**
   `faah.me` still serves the pre-PureScript generation, and the PureScript
   app at `2f3bd54` was a Vite dev entry. If the pass is still wanted, build
   `2f3bd54` in a worktree and diff that. The prebuilt `output/`, `.spago/`,
   and `.purs-ts/` directories in this checkout support it.
4. **Deployment is not configured.** CI was intentionally skipped. The site
   needs a host (any static server), immutable caching for `?v=`-stamped
   assets, compression (the WASM is ~3.9MB uncompressed), and the `404.html`
   fallback. `faah.me` does not serve this build yet.
5. **`.bb/AGENTS.md` is gitignored** by the existing `AGENTS.md` rule, so a
   fresh clone has no agent instructions. Add `!.bb/AGENTS.md` to
   `.gitignore` if it should be tracked.
6. Minor: `data-relative-date` is written by three views and read by nothing;
   `make build-js` does not run `make prerender` afterwards (the reference
   does, which completes the `?v=index.js` stamp); if miso itself needs
   patching, add a `cabal.project.dev`-style project file as the reference
   site does.

## Key files

| Path | Role |
| --- | --- |
| `src/Site/App.hs`, `Update.hs`, `Model.hs`, `Action.hs` | MVU core; effects are scheduled here, never in views |
| `src/Site/Config.hs` | every site constant, including the whole DOM contract |
| `src/Site/Platform.hs` | the only module besides widgets that touches the DOM/storage/clock |
| `src/Site/Document.hs`, `prerender/Main.hs` | head/document builder and the static generator |
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
