# Effect and data contracts

## Scheduling and ownership

`io :: IO action -> Effect ...` schedules asynchronous work. Scheduler exception handling is not a replacement for product error states: represent expected failures in completion actions. `withSink` exposes action delivery; `issue` schedules another action. Use `mount = Just Init` for initial loading.

A subscription has the shape `Sink action -> IO ()`. Static `subs` follow component lifetime; named subscriptions can start and stop from update. Use `createSub` when registering listeners so finalization removes them. An independently forked loop or third-party callback is not automatically cleaned up merely because a component disappears.

For debounce, stop the previous named subscription before starting a delay that dispatches the current query. Independently handle responses from requests already sent. Use `rAFSub` for animation frames and history subscriptions for navigation.

Sources: [Effects](https://haskell-miso.org/docs/effects/), [Subscriptions](https://haskell-miso.org/docs/subscriptions/), [Actions and update](https://haskell-miso.org/docs/thinking/update/).

## Data and lenses

Prefer `MisoString` at browser boundaries. `ms` formats supported values; parse user input with `fromMisoStringEither` instead of the throwing conversion. Qualify `Miso.String` operations where they conflict with Prelude.

Use `Miso.JSON` for fetch, decoder, and message instances. `eitherDecode` retains an error; `decode` returns an optional value. Derive through `Generic` with the required extensions or define instances explicitly. Match API field names deliberately. Qualify JSON's `(.=)` when lens updates use the same spelling. Do not assume `Data.Aeson` instances are automatically interchangeable.

`this` focuses the complete model. Use `.=` for assignment, `%=` for transformations, and numeric operators for arithmetic. Hand-written, Template Haskell, and generic lenses are alternatives; preserve the project's style rather than installing another lens package for a small change.

Sources: [MisoString](https://haskell-miso.org/docs/misostring/), [JSON](https://haskell-miso.org/docs/json/), [State and lenses](https://haskell-miso.org/docs/state-and-lenses/).

## Version-qualified HTTP example

In Miso 1.13.0.0's `Miso.Fetch` source, success has type `Response body -> action` and failure has type `Response error -> action`. Verify the installed version first. For that contract, import `Miso.Fetch` qualified and use `Fetch.body` if the action carries only the payload. Give the error payload a concrete type so `FromJSVal error` is determined. Test decoding against representative endpoint data, including missing or invalid fields.

For pure transition tests, `runEffect` requires `ComponentInfo` and returns scheduled work alongside the model. Do not claim such a test executed HTTP, timers, or browser effects.
