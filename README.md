# faah.me

Haskell + [Miso](https://haskell-miso.org) port of faah.me: a static site
rendered to `public/` by a native generator and hydrated in the browser from a
WASM bundle.

## Layout

| Path | What lives there |
| --- | --- |
| `app/Main.hs` | WASM entry point (`hs_start`), interactive reload, and the `miso` hydration call |
| `src/Site/` | the application: `App` wiring, model/update/view, routes, content queries, platform effects, widgets |
| `prerender/` | native binary that renders every route from the same views |
| `content/` | Markdown posts |
| `shaders/`, `scripts/` | GLSL sources and the build-time generators (Node and `runghc`) |
| `generated/` | generated Haskell modules; gitignored, rebuilt by `make content` |
| `styles/input.css` | Tailwind entry point; output is `static/styles.css` |
| `static/` | fonts, images, favicon, and the no-build shell |
| `public/` | build output; gitignored. This directory is the deployable artifact |

## Build

Run from the repository root. Each Makefile target crosses into the flake
shell it needs, so plain `make` is enough.

| Task | Command |
| --- | --- |
| Everything: build, optimize, prerender | `make all` |
| WASM build only | `make build` |
| Native test suite | `make test` |
| Local preview on port 8080 | `make serve` |
| CSS / content only | `make css` / `make content` |

The first run needs the Nix flake, one
`nix develop .#wasm --command npm ci` for the content and CSS generators, and
network access for `make update`. Nothing has to be installed on the host
outside Nix. `.bb/AGENTS.md` carries the architecture notes and command
details; `.bb/MIGRATION.md` records the port from the PureScript/Foldkit site.
