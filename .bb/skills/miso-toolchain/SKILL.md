---
name: miso-toolchain
description: Set up, build, run, or debug Haskell Miso applications with WASM, the GHC JavaScript backend, server rendering, Nix, Cabal, interactive reload, or CSS assets. Use for compilation, startup, FFI glue, missing events, and hydration diagnostics. Skip unrelated build systems.
---


# Miso toolchain and debugging

Read [compatibility notes](../miso-thinking/references/compatibility.md) and [build diagnosis](references/build-debug.md). Determine the project's backend, package version, and build entry points rather than assuming a sampler layout.

1. Identify the failing stage: dependency resolution, Haskell compile, linking/glue, CSS, static files, loader, event dispatch, or hydration. Read the actual command output before changing configuration.
2. Preserve existing dependency and toolchain pins unless a dependency change is part of the task. Check the compiler backend, Cabal flags, language extensions, and resolved module signatures. Nix and JavaScript package scripts are optional.
3. Use the project's documented build commands. For WASM, preserve reactor exports and loader/glue compatibility; for JS, SSR, or native targets, follow that target's entry and packaging requirements. Preserve interactive CPP behavior where present.
4. Test the narrow changed layer first. For Haskell changes, compile the intended backend; for classes, regenerate CSS; for startup/glue changes, load the generated browser app.
5. Enable `DebugEvents` for delivery problems and `DebugHydrate` for initial DOM mismatches. Scheduler work is queued and batched; avoid treating every action as a guaranteed separate paint.
6. Report the exact successful validation and any unavailable toolchain or untested browser behavior. Do not claim that upstream runtime tests were run by building this application.

Sources: [Installation](https://haskell-miso.org/docs/installation/), [Development](https://haskell-miso.org/docs/development/), [Internals](https://haskell-miso.org/docs/internals/).
