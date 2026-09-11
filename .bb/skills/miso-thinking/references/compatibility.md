# Miso compatibility and version checks

Read this when applying documentation examples to any Miso application. Documentation coverage was checked on 2026-09-10; the framework website and an application's installed release may differ.

## Establish the application context

- Read repository instructions, package definitions, dependency locks, and build scripts. Determine the resolved Miso version; a broad dependency bound is not an exact version. A toolchain lock may select a different revision from the application dependency.
- Determine the target: browser WASM, browser JavaScript, host-GHC server rendering, or Lynx native. Check the flags and extensions used by that target.
- Locate the actual source directories, application entry point, component model, CSS strategy, and asset pipeline. Do not assume a counter scaffold, Tailwind, Nix, a Makefile, or a particular output directory.
- Resolve uncertain signatures from the installed package's source or matching Haddock. Cabal source-repository dependencies may be under `dist-newstyle/src/`; other installations use a package store or external checkout. Do not hardcode generated dependency paths.
- Keep project-specific facts in the application's instructions. This reference supplies compatibility checks rather than prescribing a dependency version or build layout.

## Core type vocabulary

In the documented Component API, `Component context props model action` owns a model and update function; its view accepts context, props, and model. `App model action` specializes context and props to `()`. Use a context-aware entry point for non-unit global context. Confirm these signatures against the target release before adapting older examples.

## Confirmed differences from snippets

Observed in Miso 1.13.0.0 source on 2026-09-10. These are version-qualified examples, not a requirement to use that release. Recheck each relevant contract for the application's version.

| Topic | Observed contract |
| --- | --- |
| HTTP callbacks | `Miso.Fetch.getJSON` passes `Response body` to success and `Response error` to failure. Extract qualified `Miso.Fetch.body`, or carry the whole response. Several tutorial snippets act as if the callback receives the bare body. |
| Hydration logs | `LogLevel` has `DebugHydrate`, `DebugEvents`, `DebugAll`, and `Off`. The prerender page's `DebugPrerender` example does not match this source. |
| Hydration entry | `miso` takes an initial URI-to-component function; `prerender` accepts a component. Check context-aware signatures too. |
| Effect tests | `runEffect effect componentInfo initialModel` returns `(model, schedules)`. It requires component metadata; it does not execute those schedules. |
| Raw text | `textRaw` creates a text VDOM node and bypasses server escaping. Do not use it as a general client-side HTML insertion API. |
| Widget startup | `ts/miso/hydrate.ts` fires creation hooks during hydration too. In `ts/miso/dom.ts`, ordinary creation calls the hook before insertion; initialize through the dispatched action and verify attachment before measuring. |

Prefer module signatures over illustrative snippets, even in upstream source comments. Verify extensions and flag requirements before copying code. In particular, generic router examples can also need `DataKinds` and `DerivingStrategies`; generic JSON deriving needs the appropriate deriving extensions. The JSON docs describe an aeson flag as forthcoming: check package flags before recommending it.

Sources: [HTTP tutorial](https://haskell-miso.org/docs/thinking/update/), [prerendering](https://haskell-miso.org/docs/html-and-prerendering/), [first component](https://haskell-miso.org/docs/your-first-component/), and the inspected 1.13.0.0 `Miso.Fetch`, `Miso.Types`, `Miso.Effect`, `Miso`, and TypeScript runtime modules.
