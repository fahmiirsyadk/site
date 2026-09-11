---
name: miso-javascript
description: Integrate browser APIs or JavaScript libraries into Haskell Miso using Miso.DSL, Miso.FFI, JavaScript quasiquotes, DOMRef lifecycle hooks, or Miso.Canvas. Use for JS marshalling, widgets, charts, canvas drawing, and animation-frame integration. Skip pure styling and native Lynx APIs.
---


# Miso browser interop

Read [integration lifetime](references/integration.md) for widgets or canvas, and [compatibility notes](../miso-thinking/references/compatibility.md). Determine the application's actual compiler backend and library-loading pipeline.

1. Choose an existing typed `Miso.FFI` wrapper when it fits. Otherwise use `Miso.DSL`: `jsg` accesses a global, `(!)` reads a property, `(#)` calls an object's method, and `jsgf` calls a global function.
2. Marshal arguments with `ToJSVal` and results with `FromJSVal`. Use checked `fromJSVal` when shape is uncertain; annotate the expected Haskell type.
3. For inline JavaScript, enable `QuasiQuotes` and import `Miso.FFI.QQ (js)`. Interpolate in-scope bindings with `${binding}`; do not concatenate data into executable source. Give returning functions explicit IO result types.
4. Schedule calls from update using `io`/`io_`. Return observable outcomes as actions. Keep interop out of pure view construction.
5. Check the actual target backend and the library's loading/lifetime contract before wiring it into the page.

Source: [JavaScript EDSL and FFI](https://haskell-miso.org/docs/javascript-edsl/). Verify uncertain signatures in the resolved source or [Haddock](https://haddocks.haskell-miso.org/).
