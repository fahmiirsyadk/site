# Ownership and communication

| Need | Tool | Check |
| --- | --- | --- |
| Child reads parent data | `mountWithProps_`; `getProps` in update | Props are read-only in the child. `onPropsChanged` receives old and new values when reaction is needed. |
| Child reports a result | `mailParent`; parent's `mailbox = checkMail success failure` | Define JSON instances for the message. The recipient controls its own model. |
| Known recipient | `mail componentId` | Obtain component information from `ask`; do not invent IDs. |
| Tree-wide setting | Context-aware startup; `getContext`, `modifyContext`, `putContext` | Every consuming component must opt into context-driven re-renders. |
| Unrelated listeners | Typed `Topic`, `subscribe`, `publish` | Give decoding errors an action. Avoid publishing and mailing the same result unless duplicate delivery is intentional. |
| Hierarchy fan-out | `mailChildren`, `mailAncestors`, `mailDescendants`, or `broadcast` | Choose the intended recipient set; broadcast excludes the sender. |

Props changes repaint the child synchronously; mailbox delivery is queued. Reading a context value during view construction is separate from subscribing to future context repainting. A writer may change context without subscribing, but a theme badge that reads it normally needs `useContext` enabled.

Give models and props suitable `Eq` instances. All nested components use the same context type. A child key should identify its logical instance; changing it requests teardown and fresh state.

Sources: [Components](https://haskell-miso.org/docs/components/), [Props](https://haskell-miso.org/docs/props/), [Context](https://haskell-miso.org/docs/context/), [Communication](https://haskell-miso.org/docs/communication/).
