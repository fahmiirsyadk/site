# Migrating the site off Foldkit

PureScript · Foldkit 0.158.2 → Haskell · Miso 1.13.0.0

The two codebases are the same architecture in different languages, so most of the
work is translation rather than redesign. The parts that *aren't* translation are
worth naming precisely: Miso has no `innerHTML`, no `matchMedia`, no resource
lifetimes, and no bundler. It does have real server rendering, which the current
site never had. **The 1,813 lines of TypeScript and all nine shaders move across
untouched** — that is the leverage that makes this tractable.

> **Decisions taken after this plan was written (2026-09-11).**
>
> 1. Canvas/WebGL widgets are ported to Haskell rather than kept in TypeScript:
>    `Site.Widgets.Gl` wraps the shared WebGL calls over `Miso.DSL`, and
>    `Site.Widgets.Sea`, `.Hollow`, `.Scribble`, and `.Dither` are the four
>    ports; the GLSL sources live in `shaders/` embedded by `make shaders`.
>    `Miso.Canvas` (already in the pinned miso) covers 2D needs.
>    `three.hs`/`three-miso` were considered and rejected: they bind three.js
>    loaded from a CDN for widgets that are raw shader quads.
> 2. The 404 page stays plain — no canvas, no interactive world.
>    `NotFoundWorld` is not ported.
> 3. Dithered images keep their source image visible until the Haskell widget
>    has uploaded the image and completed its first WebGL draw. Only then does
>    `data-dither-ready='true'` hide the source; WebGL failure or context loss
>    instead exposes the source through `data-dither-fallback='true'`.
>
> Findings C, the phase-5 widget registry, and the phase-7 loop discussion
> below describe the original TypeScript-bridge approach and are kept for
> history; `.bb/AGENTS.md` carries the current architecture.
>
> **Status (2026-09-11).** Phases 0–6 are complete. The shell, pure ports,
> content pipeline, pages, widgets, and prerender/hydration all build and ship
> from this repository, and the native suite in `test/Spec.hs` covers the route
> table, the update transitions, and every widget's pure half. Phase 7 closed
> with these outcomes:
>
> * The Sea, Hollow, Dither, and Scribble loops stay in Haskell, driven by one
>   `requestAnimationFrame` per live widget. This supersedes the "move the Sea
>   frame loop into TypeScript" recommendation above (decision 1). The
>   per-frame boundary cost was never measured in isolation; the measured
>   behavior is that headless Firefox holds a 17.08 ms median frame time with
>   off-screen dithers paused, and cover-ready medians stay around 1.6–1.9 s.
> * The vitest suite is not ported. It tested the TypeScript boundary that no
>   longer exists; its pure derivations (sea motion, scroll geometry, hollow
>   mesh, dither layout, scribble scheduling, GitHub JSON) are covered by
>   `make test` instead.
> * `make optim` runs `wasm-opt -all -O2` and `wasm-tools strip`; the optimized
>   binary is 3,887,699 bytes (~3.89 MB), recorded in `.bb/AGENTS.md`.
> * The route-by-route visual pass has no clean baseline: `faah.me` serves the
>   pre-PureScript generation, and `2f3bd54` was a Vite dev entry. If it is
>   still wanted, build `2f3bd54` in a worktree and diff that; the prebuilt
>   `output/`, `.spago/`, and `.purs-ts/` directories in the checkout support
>   that without a full PureScript toolchain install.

| | |
|---|---|
| ~8,000 | lines in scope |
| 1,630 | port unchanged |
| 3,051 | TypeScript stays |
| 30 → 11 | action constructors |
| 4 | FFI shims required |

All capability claims below were verified against the resolved `miso-1.13.0.0`
checkout in `dist-newstyle/src/`, not against published documentation.

---

## 1. Two runtimes, side by side

Both are MVU. The differences that matter are in the effect model and the build.

| | `~/dev/site` — source | `~/dev/site` — target |
|---|---|---|
| Language | PureScript 0.15.16 | GHC, `wasm32-wasi` |
| Framework | Foldkit 0.158.2 on Effect 4.0.0-rc.112 | Miso 1.13.0.0 (git tag `1.13.0`) |
| Entry | `Runtime.run {init,update,view,onUrlRequest,onUrlChange}` | `startApp events (component initial update view)` |
| Update result | `{model, commands}` — a record you build | `Effect parent props model action` — a writer you sequence |
| Effects | `Fx.Effect e services a`: typed errors, `Scope`, `Ref`, services, `zipPar` | `io` / `io_` / `sync` / `issue` / `withSink`. No `MonadIO` in `Effect` |
| Commands | Named and inspectable: `Command.named "NavigateInternal"` | Anonymous schedules |
| Child state | `Submodel.submodel {slotId, model, view, toParentMessage}` | `component` mounting, or lens-focused plain views |
| Resource lifetime | `Fx.acquireRelease` — runtime owns cleanup | Lifecycle hooks that *dispatch actions*; cleanup is yours **(gap)** |
| Compile path | PureScript → TypeScript (`purs-backend-ts`) → Vite | Haskell → WASM reactor, `--export=hs_start` |
| Bundler | Vite 8 | none — `cp -r static public` + `post-link.mjs` |
| Server render | metadata only; `#root` ships empty **(not crawlable)** | `Miso.Html.Render.toHtml` + `hydrateModel` available, unused **(upgrade)** |
| Tests | vitest 4 + happy-dom — 9 files, 1,238 lines | none; no `test-suite` stanza at all **(gap)** |
| Styling | Tailwind 4.3.1, `@plugin typography`, `@custom-variant dark` | Tailwind 4.3.0, `@source "../app"` |
| DevTools | `@foldkit/devtools` + an MCP server | `LogLevel`: `DebugHydrate` / `DebugEvents` / `DebugAll` / `Off` |

**Event map.** `defaultEvents` registers only blur, change, click, contextmenu,
dblclick, focus, input, select, submit. The site's views use `onMouseEnter`,
`onMouseLeave` and `onKeyDownPreventDefault`, so the map becomes
`defaultEvents <> mouseEvents <> keyboardEvents`. Every pointer, scroll and
visibility listener lives inside the TypeScript widgets and attaches
imperatively — so *no* pointer or touch events are needed in the Haskell map.
Set it in **both** branches of the `#ifdef INTERACTIVE` split in `app/Main.hs`;
changing one and not the other gives a dev build that responds to hover and a
production build that doesn't.

---

## 2. Translation dictionary

The right-hand column is what the Miso mental model wants, not the closest
syntactic match.

| Foldkit / Effect | Miso 1.13 | What changes |
|---|---|---|
| `result model []` | `pure ()` | the no-op update stops being a value you construct |
| `result model [cmd]` | `io_ (…)` | fire-and-forget needs no message at all |
| `Command.named "X" args \_ -> …` | `io_ (…)` | both the name and the completion message disappear |
| `FoldkitUpdate.mapCommands toParent` | lens focus on the child field | child `Effect` is already over the child model; no re-wrapping |
| `Fx.zipPar a b` | two `io` schedules, two actions | model holds partial results; the view renders them |
| `Fx.Effect e _ a` typed error | an action with an error path | errors become part of the action type, deliberately |
| `Mount.define` + `Fx.acquireRelease` | `onCreatedWith` / `onBeforeDestroyed` | hooks dispatch actions; you own the release handle **(shim)** |
| `Mount.defineStreamWith` | named `startSub` / `stopSub` | or `createSub` when finalization matters |
| `HP.onMount {action}` | `onCreatedWith (\ref -> …)` | also fires during hydration — must be idempotent |
| `Submodel.submodel {slotId,…}` | `component`, keyed | `slotId` becomes the component key |
| `Document.document {title,body}`, `withCanonical` | — | no head abstraction: FFI, or let prerender emit it **(shim)** |
| `Navigation.pushUrl` | `pushURI` | direct |
| `Navigation.load` | `io_ (setLocation …)` | FFI one-liner |
| `onUrlChange` field | `routerSub` | a subscription, not a runtime field |
| `Storage.get` / `set` | `Miso.Storage.getItem` / `setItem` | returns `IO JSVal`, no `Either` — wrap with `fromJSVal` |
| `Render.afterPaint` | `rAFSub`, or `io_` after a frame | direct enough |
| `Media.prefersReducedMotion` | — | `Miso.Media` is `<video>`/`<audio>`, not media queries **(shim)** |
| `Root.toggleClass` / `setColorScheme` | — | FFI on `documentElement` **(shim)** |
| `HP.innerHtml` | — | no property or attribute reaches it **(blocker)** |
| Effect Schema decode (TS side) | `FromJSVal` / `Miso.Fetch` | 1.13 callbacks take `Response body -> action`; extract `Fetch.body` |

---

## 3. Three structural findings

These are the places where a literal translation would carry a Foldkit-shaped
workaround into a codebase that no longer needs it.

### A. The model is a product of pages; it should be a sum

Both page models are present on every route, so state outlives the page that owns
it. The symptom is already in the code: `ChangedUrl` hand-resets one field to keep
a stale interaction from surviving navigation.

```purescript
-- now
type Model =
  { route :: Route.AppRoute
  , theme :: Theme.Theme
  , routeMotion :: RouteMotion
  , home :: Home.Model
  , post :: Post.Model }

-- Update.purs, ChangedUrl:
nextHome = model.home { labInteraction = LabIdle }
```

```haskell
-- Miso idiom
data Page
  = HomePage Home.Model
  | SectionPage MisoString
  | PostPage Post.Model
  | SshPage
  | NotFoundPage MisoString

data Model = Model
  { _page   :: Page
  , _theme  :: Theme
  , _motion :: RouteMotion }
```

The `route` field disappears entirely — it was a computed duplicate of which page
is live, and the two *can* disagree today. Navigation constructs a fresh page
value, so the reset becomes structural instead of remembered. Anything that needs
the current path derives it with `routePath page`. This is the largest idiomatic
gain in the migration, and it is what the design-review question *"can two fields
disagree because one duplicates a computed value?"* is pointing at.

### B. Nineteen of thirty messages are Foldkit ceremony

`App.Message` has 30 constructors. Nineteen are `Completed*` / `Failed*` pairs
whose entire update body is `result model []` — they exist because a Foldkit
command must produce a message. `io_` produces none, so they collapse.

**Don't delete all of them.** Keep an action wherever failure should change what
is on screen: a failed GitHub fetch has a view consequence, a failed theme write
does not. The rule from the skills — *every external result becomes an action with
an error path* — still holds, but the error path is only worth naming when the
model reacts to it. Expect to land near eleven real constructors plus two or three
deliberate error actions.

### C. Resource lifetimes have to be rebuilt by hand

Foldkit's `Mount.purs` hands cleanup to the runtime. Miso's hooks dispatch
actions; they don't run IO synchronously and they carry no value from creation to
destruction, so nothing bridges acquire and release for you.

```purescript
-- now: runtime owns it
mount acquire completed failed el =
  Fx.catchAll
    (Fx.as completed (Fx.acquireRelease (acquire el) Browser.release))
    (const (Fx.succeed failed))
```

```haskell
-- Miso: you own it. One JS-side registry: Map<string, Cleanup>
foreign import javascript "mountWidget($1,$2,$3)"
  mountWidget :: MisoString -> MisoString -> JSVal -> IO ()
```

Keep the cleanup closure in a JS-side registry keyed by a stable element id, and
have `onBeforeDestroyed` dispatch an action whose `io_` calls `releaseWidget key`.
The alternative — storing the `JSVal` cleanup in the model — makes the model
non-`Eq`, non-`Show`, and ties diffing to opaque values. One wrinkle either way:
creation hooks *also* fire during hydration, so `acquire` must be idempotent.

---

## 4. Inventory and disposition

Measured, not estimated. 58 `.purs` files and 26 `.ts` files.

| Layer | Lines | Disposition | Note |
|---|---:|---|---|
| Pure logic | 1,630 | **ports as-is** | `runtime/`, `domain/`, `Route`, `RouteTransition`, `Site`, `Repository` — no framework contact |
| MVU wiring | 649 | **reshape** | shrinks: finding B removes 19 constructors, finding A removes a field |
| Views | 1,026 | **rewrite** | DSL for DSL; mechanical but wide. 5 pages + `component/` + `View.purs` |
| Browser FFI, PS side | 1,616 | **rewrite as JSFFI** | largest single chunk. `Sea.purs` alone is 354 lines of `Fx.Ref` threading |
| TypeScript, non-test | 1,813 | **unchanged** | `NotFoundWorld.ts` 636, `Sensors.ts` 270, `Sea.ts` 164, `HollowMark.ts` 163, `DitheredImage.ts` 160, `Scroll.ts` 131… |
| TypeScript tests | 1,238 | **unchanged** | they test the boundary, and the boundary doesn't move |
| Shaders | 9 files | **unchanged** | dithered-image, hollow-mark, hollow-world, sea-composite, sea-footer |
| Markdown content | 5 posts | **pipeline changes** | files keep their format; only the build step that reads them moves |
| **PureScript in scope** | **4,921** | | of which 1,630 port with no edits |

Read that table as one claim: **this is not a rewrite of the site in Haskell.** It
is a replacement of the PureScript layer sitting above an unchanged JavaScript
layer. 3,051 lines of TypeScript and every shader stay exactly as they are —
including the 636-line `NotFoundWorld.ts`, which is the piece nobody wants to port
twice.

---

## 5. Capability gaps, with evidence

| Need | Status | Evidence | Shim |
|---|---|---|---|
| Post body HTML | **none** | `textRaw = VText Nothing` (`Types.hs:1003`) only skips SSR escaping; the client does `createTextNode(n.text)` (`dom.ts:414`). And `diffProps` routes *every* property through `setAttribute` (`dom.ts:274–324`), deliberately, to stay compatible with the native runtime — so `textProp "innerHTML"` fails too. | FFI `setInnerHTML :: JSVal -> MisoString -> IO ()` from `onCreatedWith` |
| Reduced motion, dark scheme | none | no `matchMedia` anywhere in `src/` or `ts/`. `Miso.Media` is HTML media elements — load, play, pause, currentTime, duration | FFI `matchMedia` |
| Head and meta tags | none | no `Document` abstraction of any kind | FFI, or drop it in favour of real prerender (phase 6) |
| Intersection / Resize observers | not needed | absent from Miso, but already implemented in `Sea.ts` and `Scroll.ts` | leave on the JS side |
| WebGL | not needed | `Miso.Canvas` is 2D only | already in TypeScript |
| Storage errors | partial | `getItem :: Storage -> MisoString -> IO JSVal` — no `Either` | `fromJSVal`, wrap in `Maybe` |
| Named commands, Scope, services | by design | anonymous schedules; no typed-error channel | plain `IO`, `Either`, explicit actions |

**The one real blocker.** The post page renders markdown via
`HP.innerHtml input.post.html` (`src/page/post/Post.purs:75`). There is no
property, attribute, or virtual-node constructor in Miso 1.13 that injects HTML
into the live DOM — both plausible routes are closed, and closed on purpose. The
post body must go through FFI. Everything else here is a shim you write once in an
afternoon; this one interacts with hydration, so it gets its own phase.

---

## 6. The plan — seven phases

Ordered by dependency, and arranged so the risky mechanisms get proven on small
surfaces before the wide mechanical work begins. Each phase has a gate; don't
start the next one until it passes.

### Phase 0 — Foundations
*Make the target repo somewhere work can be verified.*

- Add a `test-suite` stanza — there is none today, so nothing catches anything
  until this lands. Wire up `runEffect effect componentInfo initialModel` for pure
  transition assertions; it returns `(model, schedules)` and does **not** execute
  the schedules.
- Break `app/Main.hs` into modules and delete the dead `SayHelloWorld` constructor
  (handled, constructed nowhere, and `-Wall` won't tell you).
- Extend the event map in *both* `#ifdef` branches.
- Fix the Nix-escape artifact in `static/index.js:8-9` — the template prints two
  literal apostrophes before every WASI stdout line.

**Gate:** `cabal build` clean and a green test suite containing at least one real
`runEffect` assertion.

### Phase 1 — Pure ports
*Move the 1,630 lines that never touch a framework.*

- `Domain.Content` → `Site.Content`: `publishedPosts`, `postsInSection`,
  `findPost`, `neighboringPosts`, `metadataForPath`, `absoluteImage`, `fallback`.
  Straight transliteration.
- Routing: port the hand-rolled `urlToAppRoute` / `routePath` pair as a pure
  reversible function, and property-test the round trip. **Don't reach for
  `Miso.Router` yet** — the current table is 67 lines with a runtime
  `isContentSection` guard over `thought` and `lab`, and a type-level route table
  can't express that guard without duplicating the section list. It stays an
  option later, not a prerequisite now.
- `RouteTransition`, `Site`, `Repository`.

**Gate:** tests cover the URL round trip (including trailing slashes) and every
content query, with no `Miso` import anywhere in these modules.

### Phase 2 — Content pipeline
*Replace the Vite plugin with something a bundler-less build can use.*

Today markdown-it plus the footnote plugin run inside a Vite plugin at build time,
and PureScript reads `foreign import posts :: Array Post`. Miso has no bundler, so
the seam has to move.

- **Recommended:** a Node script keeps markdown-it and emits a Haskell module —
  `Site.Content.Generated` — with the posts as literals. Add `make content` ahead
  of `cabal build`.
- The alternative is emitting JSON and fetching at runtime with `FromJSVal`. It
  keeps the binary smaller, but adds a loading state to the post page and makes
  phase 6 harder, because prerendering wants the post body available
  synchronously.
- Cost of the recommendation: roughly 100 KB of string literals compiled into a
  binary that is already 1.74 MB. It compresses well over the wire.

**Gate:** `make content` regenerates deterministically, and phase 1's pure queries
run against the generated module in tests.

### Phase 3 — Model, actions, update
*The idiom core. All three findings land here.*

- Route-indexed `Page` sum (finding A). The `route` field goes away.
- Collapse the action type (finding B), keeping error actions only where the model
  reacts.
- Translate the update into `Effect`; child updates focus through a lens instead
  of re-wrapping messages.
- Theme: use `hydrateModel :: Maybe (IO model)` to read `localStorage` so the
  first model agrees with the pre-paint inline script in `index.html`. **That
  script must survive verbatim** — it runs before WASM loads and it is the only
  thing preventing a flash of the wrong theme.

**Gate:** `runEffect` tests cover every navigation transition — explicitly
including the one that used to need the manual `labInteraction` reset. Assert the
new page value is fresh.

### Phase 4 — Views, without widgets
*1,026 lines of DSL translation, deliberately boring.*

- Translate element for element: `HH.div` → `H.div_`, `HP.class` → `P.class_`,
  attribute lists throughout.
- Leave every mount point as a bare element with a stable `id`. No `onCreatedWith`
  in this phase — the widgets come next, and mixing the two makes failures
  ambiguous.
- Point Tailwind's `@source` at wherever the view modules live. Keep every class
  string a literal; concatenated or computed names won't be found by the scanner,
  exactly as in PureScript today.

**Gate:** every route renders statically, and the generated `styles.css` class
list diffs clean against the old build's.

### Phase 5 — The JavaScript boundary
*All the FFI at once — it's one skill, and splitting it wastes the ramp-up.*

- Shims: `setInnerHTML`, `matchMedia` (reduced motion and dark scheme), head/meta
  sync, `resetScroll`, `setLocation`.
- The widget registry from finding C: one JS module holding
  `Map<string, Cleanup>`, with `Mount.ts` as the single entry point the existing
  five widgets register into. This is where `Fx.acquireRelease` gets reimplemented
  by hand.
- Post body: `onCreatedWith (SetPostHtml ref)` → `io_ (setInnerHTML ref html)`,
  guarded so hydration doesn't inject twice.
- GitHub: `Fx.zipPar` becomes two `Miso.Fetch.getJSON` calls issuing two actions,
  with the model holding `Maybe Profile` and `Maybe Contributions` and the view
  rendering partial state. Watch the 1.13 signature — callbacks receive
  `Response body -> action`, so extract `Fetch.body`, and the error callback needs
  a concrete type to get `FromJSVal`.
- Reading progress: `Mount.defineStreamWith` becomes a named `startSub`/`stopSub`
  scoped to the post page, wrapping `Scroll.ts` unchanged.

**Gate:** navigate a route ten times and assert the registry is empty afterwards —
no leaked observers, no orphaned rAF loops.

### Phase 6 — Prerender and hydrate
*The upgrade the current site never had.*

- Render each route with `Miso.Html.Render.toHtml`. **Order matters in the
  Makefile:** `build` does `rm -rf public` at line 28 and then `cp -r static
  public`, so generation has to run *after* the copy. Anything written into
  `static/` or placed in `public/` early is destroyed.
- Move the entry point from `startApp` to `miso (\uri -> app uri)`, with
  `hydrateModel` supplying the theme.
- Set `LogLevel` to `DebugHydrate` while bringing this up. Hydration mismatch is
  the failure mode and that flag is what names it. (The published docs'
  `DebugPrerender` example is wrong — the constructors are `DebugHydrate`,
  `DebugEvents`, `DebugAll`, `Off`.)
- Check which side of miso's `ssr` cabal flag you're on: `text` only becomes
  `VText Nothing . htmlEncode` under `#ifdef SSR`. Get this wrong and you ship
  either escaped markup or unescaped content.
- `prerender-meta.ts` becomes unnecessary for metadata — the head comes out of the
  same render — but keep whatever generates `sitemap.xml` and `robots.txt`.

**Gate:** `curl` on each route returns full content markup, not an empty root, and
`DebugHydrate` reports no mismatch on any route.

### Phase 7 — Parity and measurement
*Close the two questions that need numbers rather than opinions.*

- **The Sea frame loop.** It currently runs in PureScript, threading eight
  `Fx.Ref`s and calling `drawSea` once per frame. Across a WASM boundary that
  marshalling has a cost nobody here has measured. Measure it — and note the idiom
  argument points the same way as the likely result: those eight refs are mutable
  state that never influences the view, so in Miso terms they are not model, and
  state that isn't model and doesn't affect rendering belongs on the JS side.
  Moving the loop wholly into `Sea.ts`, with Haskell only starting, stopping, and
  configuring it, is both faster and more honest.
- Decide where the vitest suite lives, then run it.
- `wasm-opt -O2` and `wasm-tools strip`, and record the binary size against the
  1.74 MB baseline.

**Gate:** frame timing measured on both sides of the boundary, a decision
recorded, and every route visually diffed against the live site.

---

## 7. Risk register

Ordered by how much rework each one causes if it's discovered late.

| Risk | Mitigation | Phase |
|---|---|---|
| **Nothing verifies anything.** No test suite in the target repo, so every finding below stays invisible until something breaks in a browser. | Phase 0 exists for this reason and nothing else. It goes first. | 0 |
| **innerHTML fights hydration.** The injecting hook fires on hydration too, so the post body can be written twice or diffed against. | Inject once, guarded on a data attribute. Better: render the post HTML into the prerendered output and have the hook skip when the element already has children. | 5–6 |
| **Tailwind silently loses classes.** `@source` scans for class-shaped literals; anything concatenated or computed is invisible to it. | Keep class strings literal. Diff the generated class list against the old build — that's the phase 4 gate. | 4 |
| **Per-frame boundary cost.** Unmeasured, and it decides where the render loop lives. | Measure in phase 7, on both sides. Don't guess; the answer changes the architecture of one widget. | 7 |
| **`rm -rf public`.** The Makefile wipes the directory on every build, so anything hand-placed or generated too early is gone. | Generate prerendered output after `cp -r static public`, never into `static/`. | 6 |
| **Event map divergence.** The `#ifdef INTERACTIVE` split makes it easy to extend one branch and forget the other. | Define the map once as a named binding and reference it from both branches. | 0 |
| **Trailing-slash regressions.** Routes are `/`, `/ssh/`, `/{section}/`, `/{section}/{slug}/` and the round trip has to be exact. | Property-test `routePath . urlToRoute` as identity over generated inputs. | 1 |
| **Theme flash.** Three things must agree: the inline pre-paint script, `hydrateModel`, and the prerendered class on `<html>`. | Keep the inline script byte-identical; make `hydrateModel` read the same key; assert agreement in the phase 6 gate. | 3, 6 |
| **Binary size.** Content literals land inside a 1.74 MB WASM binary. | Record the size at each phase boundary. If it becomes a problem the JSON-fetch alternative from phase 2 is still open. | 2, 7 |

---

## 8. Decisions to make now

Five choices that shape phases 2 through 7. Each has a recommendation and the
reason behind it; none needs to be right first time except the first.

**Content pipeline — *generated Haskell module.*** Literals in a generated module
keep the post page synchronous, which phase 6 depends on, and keep one generator
rather than a fetch path plus a loading state. The cost is binary size. Fetched
JSON stays available as a fallback if that cost turns out to matter.

**Routing — *port the hand-rolled pair.*** 67 lines that already round-trip,
versus a servant-shaped type-level table that can't express the `isContentSection`
guard without duplicating the section list. `Miso.Router` earns its `DataKinds`
and `DerivingStrategies` later, if the route table grows.

**Sea frame loop — *move it into TypeScript.*** Eight mutable refs that never
reach the view are not model. Independent of what the timing measurement says,
that state belongs on the JS side of the boundary — the performance argument and
the idiom argument agree here, which is unusual enough to act on.

**Where the TypeScript lives — *copy it into site-miso.*** Move the widgets,
shaders, and the vitest suite into the new repo rather than depending on the old
one. It's the tested boundary and it should sit next to the code that calls it.
This also lets `~/dev/site` be archived whole instead of half-retired — worth
noting that repo currently carries 1.5 GB including a 92 MB vendored `purs`
binary, a 148-directory `output/` and a 241-directory `corefn/`, none of which
follows.

**Widget mounting — *one registry, not five.*** A single `Mount.ts` owning
`Map<string, Cleanup>` gives one place where the acquire/release contract is
implemented and one place to assert emptiness in the phase 5 gate. Five
independent per-element mounts give five places for a leak to hide.

---

*Verified against the resolved `miso-1.13.0.0` checkout in `dist-newstyle/src/` —
not against published documentation. Line counts measured with `wc -l` over
`~/dev/site/src`; 58 `.purs` files, 26 `.ts` files. Source repo `~/dev/site`,
target repo `~/dev/site`. 10 September 2026.*
