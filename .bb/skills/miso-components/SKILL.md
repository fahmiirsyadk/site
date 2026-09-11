---
name: miso-components
description: Compose Haskell Miso components and connect local state, props, global context, mailboxes, or PubSub. Use for child state ownership, stale context rendering, props updates, component remounts, or communication between components.
---


# Miso components and communication

Read [ownership and communication](references/communication.md) and [compatibility notes](../miso-thinking/references/compatibility.md). Inspect the application's model and entry point before choosing a communication mechanism.

1. Identify the owner of each mutable value. Use plain views when they do not need independent state or lifetime.
2. Build components through `component`; use record updates for hooks, mailbox, and subscriptions. Keep `Component context props model action` parameters explicit around boundaries. `App` fixes context and props to `()`.
3. Mount browser children with stable keys. Use `mountWithProps_ key props child` for parent data and `key +> child` for unit props. Preserve child model state when props change unless the feature intentionally resets it.
4. Choose the narrowest communication mechanism in the reference. Do not mirror editable data into both parent and child models without defining an explicit draft/commit protocol.
5. Seed non-unit global context using a context-aware entry point. Enable `useContext = True` on each component that must repaint when it changes; verify nested consumers too.
6. Decode mail and topic payloads into typed actions, including failure actions. Keep resource acquisition and release aligned with mount/unmount or subscriptions.
7. Verify changed props, context repainting, malformed messages, stable-key updates, and deliberate remounts as relevant. Use the pinned signatures to resolve ambiguous examples.

For native mounting use `miso-native`; its cross-thread identity requirements differ from browser component keys.
