---
name: miso-views
description: Build or fix Haskell Miso views, forms, DOM events, text, keyed lists, fragments, attributes, CSS, or Tailwind styling. Use for missing keyboard/pointer events and DOM lifecycle hooks. Skip copy-only edits and native Lynx element work.
---


# Miso views and styling

Read [view contracts](references/view-contracts.md) for the relevant DOM feature and [compatibility notes](../miso-thinking/references/compatibility.md). Inspect the application's existing CSS and asset setup.

1. Keep `view :: context -> props -> model -> View context model action` pure. Prefer HTML/SVG/MathML smart constructors and extracted view functions.
2. Render changing values with `text` and `ms`. Use typed property helpers; derive conditional classes from the model. Preserve semantic HTML, labels, keyboard access, and visible focus states.
3. For lists, use stable domain IDs and unique keys on every sibling participating in keyed diffing. A changed component key intentionally discards its previous instance. Never key reorderable data by position.
4. Turn inputs and events into actions. Pair controlled values with the action that updates them. Register every needed event family at application startup, including interactive startup.
5. Use element lifecycle actions when an integration needs the actual `DOMRef`; delegate external work to `miso-javascript`.
6. Preserve the application's styling strategy. Miso supports structured inline CSS and external stylesheets; Tailwind is optional. If a utility-class scanner is used, ensure it includes the actual Haskell source directories and use discoverable complete class names. Use structured inline CSS for genuinely dynamic numeric values when appropriate.
7. Regenerate assets after styling changes when the project's pipeline requires it. Check empty, long-content, error, narrow-screen, focus, and disabled states as relevant. For event failures, enable `DebugEvents` locally and verify dispatch before changing update logic.

Read [the route map](../miso-thinking/references/docs-map.md) to locate official examples for a specific element or behavior.
