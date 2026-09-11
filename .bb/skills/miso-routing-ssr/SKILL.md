---
name: miso-routing-ssr
description: Implement Haskell Miso URL routes, typed links, browser history, prerendering, hydration, static page generation, or deep-link loading. Use for SEO markup, server/client initial-state mismatches, and back/forward navigation. Skip documentation route inventory unless application routing is also requested.
---


# Miso routing and prerendering

Read [routing and hydration contracts](references/routing-hydration.md) and [compatibility notes](../miso-thinking/references/compatibility.md). Inspect whether the application already draws, hydrates, or generates HTML, and extend its existing pipeline accordingly.

1. Define a route sum type and URL examples, including missing/invalid routes and query parameters. Verify parse/print behavior with `Miso.Router`; put specific generic constructors before catch-all forms.
2. Render actual links with route-derived hrefs. Use navigation actions and `pushRoute` for SPA transitions. Initialize from the current URL, then subscribe with `routerSub`; handle parse failures.
3. Determine whether the task needs client drawing, static HTML, or shared server data. Keep one view definition for server output and client hydration.
4. Generate every intended static route using an SSR-enabled executable and `toHtml`, then start the client with the matching hydration entry point. Match initial model, props, context, mount structure, and URL.
5. Use `hydrateModel` only when dynamic state must be restored, with appropriate safe serialization and decoding. Keep secrets out of client state.
6. Verify hard reloads on deep links, back/forward, query changes, unknown routes, initial HTML without WASM, and browser hydration diagnostics as applicable. A successful compiler run does not establish hydration parity.
