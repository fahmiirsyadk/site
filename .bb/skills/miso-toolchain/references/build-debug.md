# Build and debug Miso applications

Read the application's package files and documented commands before choosing a build. Miso supports several targets; build and asset layout are application choices.

| Target or stage | Establish first | Verify |
| --- | --- | --- |
| Browser WASM | WASM compiler/package tools, reactor linker options, exported entry, and loader | Haskell compilation, post-link JS FFI glue, matching WASM/loader assets, and browser startup |
| Browser JavaScript | GHC JS compiler/package tools and bundling/serving setup | Target compilation, packaged JS/runtime, and browser startup |
| Server/static HTML | Host GHC executable, Miso SSR flags, shared views, and route/data inputs | Escaping, output HTML, and client hydration parity when hydration is required |
| Lynx native | Native flag, GHC JS setup, bundle tooling, and platform shell | Follow `miso-native`; a browser build does not validate native behavior |
| Styles/assets | External CSS, structured inline CSS, or optional preprocessing/scanning | Only rebuild assets the project generates; verify the actual source scan paths if applicable |
| Interactive reload | Compiler support, interactive entry point, watched sources, and configured port | Source reload, event registration, and any independently watched assets |

## Choose commands from evidence

For Cabal projects, inspect the executable name, flags, and selected compiler. Use the project's wrapper or explicit backend tools when a plain `cabal build` would target the wrong compiler. If Nix is used, inspect the available flake outputs before selecting a shell; do not assume a `.#wasm` output exists. If Make or package scripts exist, read their targets before running them.

The official sampler demonstrates WASM reactor linking, an `hs_start` export, post-link glue, and a WASI loader. Other applications can package these differently. Verify the entry/export names and generated asset paths together. A host-GHC compilation alone does not validate browser startup.

Trace output-directory ownership. If a build step removes or replaces an output directory, generate prerendered pages after that step or explicitly preserve them. Avoid broad cleaning or package-index updates as a default response to unrelated errors.

## Debug the failing layer

For compilation, check imports, extensions, resolved signatures, and backend flags. For blank pages, check loader and asset responses before changing the model. For missing actions, inspect the startup event map and use event diagnostics. For server/client mismatch, use hydration diagnostics and compare initial route, data, context, and markup.

Rendering follows queued action batches, not necessarily one paint per action. Read scheduler/runtime source only when a behavior cannot be explained at the application layer.

Sources: [Installation](https://haskell-miso.org/docs/installation/), [Development](https://haskell-miso.org/docs/development/), [Internals](https://haskell-miso.org/docs/internals/).
