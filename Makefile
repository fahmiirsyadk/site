.PHONY: all update content shaders geometry css watch-css build optim prerender serve test watch watch-preview

# Two supported ways to run:
#   * plain `make all` from the host: every phase crosses into the flake shell
#     it needs (the WASM toolchain, the native shell for prerender/tests, and
#     the WASM shell again for Node/npm), so the host needs only `nix`;
#   * `nix develop .#wasm --command make all`: the WASM toolchain, Node and npm
#     are already on PATH, and the native phases cross into the default shell.
# GNU Make drops `#` as a comment in variable assignments, so the flake
# attribute needs `.\#wasm`.
WASM_SHELL   := nix develop .\#wasm --command
NATIVE_SHELL := nix develop . --command
GHCJS_SHELL  := nix develop .\#ghcjs --command

ifeq ($(NIX_ENFORCE_NO_NATIVE),1)
WASM_RUN      :=
NODE_RUN      :=
GHCJS_RUN     :=
else
WASM_RUN      := $(WASM_SHELL)
NODE_RUN      := $(WASM_SHELL)
GHCJS_RUN     := $(GHCJS_SHELL)
endif

# Native phases always cross into the default flake shell: the host GHC cannot
# link against its GMP from inside the WASM shell, and the host needs only
# `nix`, not a GHC of its own. The shell evaluation is cached, so this is a few
# seconds, not a second toolchain build.
NATIVE_CABAL  := $(NATIVE_SHELL) cabal
NATIVE_RUNGHC := $(NATIVE_SHELL) runghc

CABAL_ARGS += --allow-newer=base,template-haskell --with-compiler=wasm32-wasi-ghc --with-hc-pkg=wasm32-wasi-ghc-pkg --with-hsc2hs=wasm32-wasi-hsc2hs --with-haddock=wasm32-wasi-haddock
RELEASE_CHANNEL := https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/ghcup-wasm-0.0.9.yaml
WASM_BOOTSTRAP := https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/bootstrap.sh

# `build` replaces public/, and the prerender executable is native-only, so the
# phases stay explicit and ordered: build, then optimize, then render the
# final optimized WASM hash into the generated pages.
all: update
	+$(MAKE) build
	+$(MAKE) optim
	+$(MAKE) prerender

js: update-js build-js

update:
	$(WASM_RUN) wasm32-wasi-cabal update

# Parses content/*.md into generated/Site/Content/Generated.hs, embeds the
# shaders, and packs the hollow mesh. Any cabal build of the library needs
# these modules, so they run before build and test.
content: shaders geometry
	$(NODE_RUN) node scripts/content/generate.mjs

shaders:
	$(NODE_RUN) node scripts/shaders/generate.mjs

geometry: generated/Site/Widgets/HollowGeometry.hs

# Site.HollowGeometry is the only owner of the mesh; the native generator
# packs what it exports. Regenerate only when either side changed, so the
# generated module does not force a rebuild on every `make content`.
generated/Site/Widgets/HollowGeometry.hs: src/Site/HollowGeometry.hs scripts/hollow/Generate.hs
	$(NATIVE_RUNGHC) -isrc scripts/hollow/Generate.hs

css:
	$(NODE_RUN) npm run build:css

watch-css:
	$(NODE_RUN) npm run watch:css

repl: content css update
	$(WASM_RUN) wasm32-wasi-cabal repl app -finteractive --repl-options='-fghci-browser -fghci-browser-port=8080'

watch: content
	$(WASM_RUN) ghciwatch --after-startup-ghci :main --before-reload-ghci 'make content' --after-reload-ghci :main --watch app --watch src --watch content --watch shaders --debounce 50ms --command 'wasm32-wasi-cabal repl app -finteractive --repl-options="-fghci-browser -fghci-browser-port=8080"'

# Production-parity live preview: watches the sources and runs the real
# `make build` + `make prerender` on change, served on port 8080. CSS edits
# skip the rebuild and only rerun Tailwind. `optim` is deliberately left out;
# run `make all` before shipping.
watch-preview: content css
	$(NODE_RUN) node scripts/watch-preview.mjs

build: content css
	$(WASM_RUN) bash -c 'set -e; \
		wasm32-wasi-cabal build exe:app; \
		rm -rf public; \
		cp -r static public; \
		my_wasm=$$(wasm32-wasi-cabal list-bin app | tail -n 1); \
		$$(wasm32-wasi-ghc --print-libdir)/post-link.mjs --input $$my_wasm --output public/ghc_wasm_jsffi.js; \
		cp -v $$my_wasm public/'

optim:
	$(WASM_RUN) bash -c 'set -e; \
		wasm-opt -all -O2 public/app.wasm -o public/app.wasm; \
		wasm-tools strip -o public/app.wasm public/app.wasm'

# Native. Renders public/<route>/index.html plus sitemap.xml, robots.txt and
# 404.html from the shared views. Run after `make build` (which replaces
# public/) and after `make optim` when the optimized WASM should be what the
# generated pages load.
prerender: content
	$(NATIVE_CABAL) run exe:prerender

serve:
	@if [ ! -f public/app.wasm ] || [ ! -f public/index.js ] || [ ! -f public/styles.css ]; then \
		$(MAKE) all; \
	elif [ ! -f public/404.html ]; then \
		$(MAKE) prerender; \
	fi
	$(WASM_RUN) http-server public -p 8080 -c-1

# Native. Route table and update transitions, no browser.
test: content
	$(NATIVE_CABAL) test

clean:
	rm -rf dist-newstyle public

update-js:
	$(GHCJS_RUN) cabal update --with-ghc=javascript-unknown-ghcjs-ghc --with-hc-pkg=javascript-unknown-ghcjs-ghc-pkg

build-js: content css
	$(GHCJS_RUN) bash -c 'set -e; \
		cabal build exe:app --with-ghc=javascript-unknown-ghcjs-ghc --with-hc-pkg=javascript-unknown-ghcjs-ghc-pkg; \
		cp -v ./dist-newstyle/build/javascript-ghcjs/ghc-9.12.2/*/x/app/build/app/app.jsexe/all.js .; \
		rm -rf public; \
		cp -rv static public; \
		bunx --bun swc ./all.js -o public/index.js'

ghcup-update:
	cabal update $(CABAL_ARGS)

ghcup-build: | install-wasm-via-ghcup ghcup-update
	. ~/.ghc-wasm/env && \
		cabal build $(CABAL_ARGS)

install-wasm-via-ghcup:
	curl $(WASM_BOOTSTRAP) | SKIP_GHC=1 sh
	. ~/.ghc-wasm/env && \
		ghcup config add-release-channel $(RELEASE_CHANNEL) && \
		ghcup install ghc --set wasm32-wasi-9.15 -- $$CONFIGURE_ARGS
