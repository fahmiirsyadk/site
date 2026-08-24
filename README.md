# Faah · Foldkit site

This is the Faah site, built with Foldkit and Effect. The site currently runs
as a client-rendered SPA with `Runtime.run`; the browser owns the initial
render and route transitions.

## Development

```bash
pnpm install
pnpm dev
pnpm build
pnpm preview
```

`purs-backend-ts` is installed from the vendored archive under `vendor/`, so
normal development does not require a sibling backend repository or an npm
release. `pnpm check:backend` verifies the archive checksum and installed CLI.
The PureScript compiler products live under `corefn/`; generated TypeScript
modules live under `output/`. `scripts/build-purescript.ts` regenerates the
`.purs-ts-roots` manifest from direct TypeScript host imports, so `spago.yaml`
does not need a hardcoded module list.

The production build writes the SPA bundle under `dist/`, prerenders unique
document metadata for every public route, and emits `sitemap.xml` and
`robots.txt`.

The application core is PureScript-owned in `src/app/`: `Core` is the public
facade, `Message` and `Command` hold typed internal alternatives, `Route`
holds the route ADT, `Model` composes root and page state, and `View` composes
the document and pages. `App.Wire` owns the raw `_tag` transport records,
codecs, and canonical tag registries used at the Foldkit/JavaScript boundary.
Page-owned state lives beside its page in
`src/page/home/Model.purs` and `src/page/post/Model.purs`; shared domain state
is limited to genuinely shared values such as the theme. Page views are
message-polymorphic pure trees, and only `App.View` interprets the tree with
Foldkit's `HtmlBuilder` once. The tree uses a small Halogen-style DSL (`HH.*`
and `HP.*`) backed by opaque PureScript types. Its node and property algebra is
interpreted by the strict, discriminated TypeScript adapter in
`src/platform/browser/foldkit-html.ts`.

`src/entry.ts` is only the Vite boot module. Native browser executors are
isolated under `src/platform/browser`: Foldkit runtime, Effect Command, Mount,
Html, DOM, and WebGL adapters live there behind minimal TypeScript FFI
re-exports. PureScript modules and their FFI providers are compiled or copied
to TypeScript by the
`purs-ts` backend; there is no generated Bridge declaration layer. The
remaining TypeScript owns build-time content compilation and browser-specific
WebGL, shader, clock, and cover effects. Canvases are declared by PureScript
views and acquire their resources through Foldkit Mounts, so the runtime owns
cleanup when a view leaves the tree.

Runtime calculations follow the same boundary. `Runtime.Canvas` owns raster
sizing, `Runtime.Dither` owns dither colors, Bayer data, texture layout, and
frame decisions, `Runtime.Frame` owns shared frame timing, and
`Runtime.SeaMotion` and `Runtime.HollowMotion` own independent interaction state
transitions. `Runtime.HollowGeometry` owns the split sphere
and cube mesh, and `Runtime.Scribble` owns scribble data, selection, keyframes,
and animation timing. `App.Wire.Message` constructs the complete Foldkit result
envelopes that browser adapters pass back to PureScript.
The Html tree algebra and recursive traversal also live in PureScript. The
corresponding TypeScript files only execute Foldkit constructors, DOM APIs,
WebGL calls, observers, and animation frames. Shader programs are `.vert` and
`.frag` assets rather than TypeScript strings. Runtime message-tag recognition
comes from `App.Wire.Message`; the same canonical registries also drive the
generated TypeScript unions, avoiding a second handwritten tag allowlist.

## Verification

```bash
pnpm check
pnpm lint
```

`pnpm check` runs the TypeScript FFI check, PureScript build, generated-output
gate, TypeScript typecheck, Vitest suites, and Foldkit Scene integration tests. PureScript output
is rebuilt automatically by `pnpm dev` and `pnpm build`. See
[`docs/purs-ts-direct-output.md`](docs/purs-ts-direct-output.md) for the
backend boundary, FFI policy, and verified commands.

## Content

Markdown content lives in `src/content/` and is parsed and rendered during the
Vite build, so MarkdownIt is not shipped in the browser bundle. Only published
frontmatter records enter the runtime repository and generated metadata.
`Domain.Content` owns publication filtering, ordering, lookup, neighboring-post
selection, and metadata fallback policy. The TypeScript content adapters only
load Vite modules, format locale dates, parse Markdown during the build, and
write generated metadata into HTML or the DOM. Site
assets live under `public/`; original source assets, retired content assets,
reference material, and migration notes are retained under `archived/`.

Markdown images are dithered by default. Append `#no-dither` to an image URL
when the original pixels must remain readable, such as screenshots, tables,
charts, or text-heavy reports:

```markdown
![Quarterly report](/assets/images/quarterly-report.png#no-dither)
```

The marker is removed from the rendered image URL. Alternative text and an
optional Markdown image title continue to work normally.

Animated GIFs are rendered as native images so their animation is preserved.
MP4 links are rendered as native, controls-enabled videos. Neither media type
is sent through the still-image dither shader; this also avoids freezing GIFs
on their first frame.
