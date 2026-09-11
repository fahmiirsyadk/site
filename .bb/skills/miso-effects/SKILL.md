---
name: miso-effects
description: Implement Haskell Miso update functions, asynchronous HTTP/JSON loading, subscriptions, timers, debounce, WebSockets, lens-based state transitions, or error handling. Use for effect ordering, resource leaks, stale async results, and Miso data decoding.
---


# Miso effects and data

Read [effect and data contracts](references/effects-data.md) and [compatibility notes](../miso-thinking/references/compatibility.md).

1. Define actions for starting work and receiving success or failure. Represent loading state coherently in the model. Handle invalid input and remote failure explicitly.
2. Update state with `Miso.Lens` or state operations. `Effect` records schedules; it has no `MonadIO` instance. Use `io` when work returns an action and `io_` when no result matters. Reserve `sync` for short ordered operations because it blocks scheduling.
3. Read the installed version's HTTP callback signatures. For example, Miso 1.13.0.0's `getJSON` supplies response wrappers, not bare decoded values. Preserve metadata when needed; do not assume tutorial callback shapes apply to every release.
4. For ongoing sources use `subs` or named `startSub`/`stopSub`. Prefer built-in subscription modules. Use bracketed acquisition/release for custom listeners.
5. For debounced or replaceable work, define who cancels old work and how results are associated with the current request. A request identifier or query comparison can reject late results; merely delaying dispatch does not cancel an already running request.
6. Decode external values safely and return failures to update. Keep rendering and JSON classes distinct from JavaScript marshalling classes.
7. Check meaningful transition sequences: failure then retry, input changes while loading, out-of-order completion, and unmount while subscribed. Test only relevant scenarios, with the appropriate backend for IO behavior.
