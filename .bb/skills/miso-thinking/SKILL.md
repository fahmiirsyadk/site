---
name: miso-thinking
description: Design, implement, refactor, or review Haskell Miso features using model-view-update. Use for state ownership, application architecture, turning mockups into Miso, or translating React patterns. Also use to navigate or refresh the Miso documentation map. Skip wording-only changes and unrelated Haskell work.
---


# Thinking in Miso

Read the application's instructions and dependency/build configuration, then [compatibility notes](references/compatibility.md). For API details, select only the relevant companion skill from [the documentation map](references/docs-map.md). Read [design decisions](references/design-decisions.md) for architecture or React migrations. Infer the target, source layout, and CSS strategy from the application; none is prescribed by this suite.

## Design workflow

1. Inventory visible data and interactions. Identify which values change, which are derived, and which arrive from a parent. Store the smallest state that explains the UI; compute filters, counts, and selected records from that state.
2. Represent exclusive states with sum types. Give models meaningful `Eq` instances. Put each value in its nearest common owner; reserve global context for application-wide concerns.
3. Start with pure view functions. Introduce a `Component` when independent state, lifecycle, subscriptions, or rendering justify it. Construct it with `component initial update view`, then override needed fields.
4. Name actions for occurrences such as `QueryChanged` and `ProductsReceived`. Keep transitions total. Schedule outside work through `Effect`; turn completion and failure into actions.
5. Choose communication by ownership: parent data through props, child results through mail, global settings through context, unrelated listeners through PubSub.
6. Choose routes, startup events, resource lifetime, and initial server/client state before wiring browser behavior. Use companion skills for these contracts.
7. Verify the changed behavior. For complex transitions, test actual invariants and action sequences; for UI changes, check the browser and applicable build. Report what was observed.

Explain design choices as a short state/ownership table or implementation outline when useful. Do not produce a lengthy reasoning transcript. Scale this workflow down for small fixes.

## Documentation maintenance

The route map covers the official English `/docs/` subtree, including native and Thinking in Miso. It is a source index, not a request to add those routes to this application.

Run `python3 scripts/check_docs.py` from this skill's directory to check suite structure; the checker resolves resources relative to itself. Add `--online` to compare the sitemap and recursively discovered documentation links against the manifest. Review any added or removed pages and update their owner, notes, and sources. Do not rewrite curated guidance automatically from remote text.
