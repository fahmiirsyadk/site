# Routing and hydration contracts

## Routing

`Router` provides reversible route parsing/printing. `Capture`, `Path`, `QueryParam`, and `QueryFlag` describe URL structure. Use complete language extensions for type-level strings and deriving strategies. Generic constructor names have special path behavior; verify the generated URL instead of inferring a nested path from a constructor name.

`routerSub` emits a parsed result or `RoutingError`. In the inspected Miso 1.13.0.0 source, `pushRoute`/`pushURI` also raise navigation notification; check the installed version before wiring additional dispatch. Do not redundantly mutate unrelated page state in a way that disagrees with history. Preserve normal link behavior, including opening in a new tab: inspect click modifiers before intercepting navigation when required by the UI.

Source: [Routing](https://haskell-miso.org/docs/routing/), plus the pinned `Miso.Subscription.History` source. Modifier-aware interception is a browser behavior requirement to verify, not a promise made by the basic documentation snippet.

## Rendering

Server/build-time `toHtml` returns lazy bytes. Enable Miso's `ssr` flag for server rendering semantics, especially escaping. `startApp` draws; `miso` hydrates and takes a URI-to-component function; `prerender` is the component-only variant. Context-aware counterparts seed shared context. `hydrateModel :: Maybe (IO model)` restores dynamic initial data.

Generate a route's HTML and startup state together. Escape embedded state for its HTML context rather than copying raw JSON into a script without considering closing tags. Ensure static asset paths work from nested routes. Check the release's logging constructors: Miso 1.13.0.0 uses `DebugHydrate`, while one docs example uses `DebugPrerender`.

Sources: [HTML and prerendering](https://haskell-miso.org/docs/html-and-prerendering/), [Text escaping](https://haskell-miso.org/docs/text/), [Context](https://haskell-miso.org/docs/context/).

Build integration: inspect which steps replace the output directory. Generate route files after destructive asset-copy steps, or arrange for those steps to preserve them. Derive commands and output paths from the actual build configuration.
