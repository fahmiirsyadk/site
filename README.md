# site

Personal site / blog — a static site generator built in **Haskell** with
[Slick](https://github.com/ChrisPenner/slick) (Shake + Pandoc) and
[Lucid](https://hackage.haskell.org/package/lucid) for typed HTML, styled with
Tailwind CSS. Content is Markdown; output is fully static HTML.

This replaces the previous PureScript/Halogen + Quartz implementation.

## Stack

- **Shake** build engine (via Slick) — incremental, dependency-tracked builds
- **Pandoc** (Slick) for Markdown → HTML, with footnotes enabled
- **Lucid** for type-safe HTML templating
- **Tailwind CSS** (standalone CLI) for styling
- Vanilla JS, no framework:
  - `gfx/gfx.js` — WebGL boot scene, cube logo, and sea/footer shader
  - `js/spa.js` — client-side soft navigation (View Transitions)
  - `js/theme.js` — light/dark theme toggle
  - `js/cover.js` — ordered-dither duotone article covers

## Layout

```
app/Main.hs        Shake rules: content pipeline, routes, build outputs
src/Site/          layout, head, nav, footer, theme, components
src/Page/          home, post, section, about page templates
src/Dev.hs         dev server (warp) + file watcher
site/content/      Markdown content (articles, projects, til, …)
css/style.css      Tailwind entry
public/            static assets (banners, images, fonts, shaders)
gfx/, js/          client-side scripts (copied to the build output)
```

## Develop

```sh
# install the CSS toolchain (Tailwind, autoprefixer)
npm install

# one-off build -> build/
cabal run site

# dev server with rebuild-on-change at http://localhost:3000
cabal run site -- serve --port 3000
```

> Note: the dev watcher rebuilds content/asset changes. Changes to Haskell
> source (`src/`, `app/`) require restarting the server to recompile the binary.

The generated site is written to `build/` (git-ignored).

## Deploy

The site is fully static. Build it, then publish the generated `build/`
directory to Cloudflare Pages (currently uploaded manually via the dashboard):

```sh
cabal run site        # writes the static site to ./build
# then drag-and-drop ./build into Cloudflare Pages
```
