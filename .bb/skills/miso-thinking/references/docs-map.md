# Miso documentation route map

Checked 2026-09-10 against the [official sitemap](https://haskell-miso.org/sitemap.xml) and recursively followed same-host documentation links. All 41 routes returned HTTP 200: 40 topic pages and the `/docs/` entry, which currently repeats the introduction. This maps documentation coverage; these are not application routes.

Select a skill/reference by task. Notes summarize each route; consult its official page for API examples, then verify against the pinned dependency. Native guidance applies only when building for Lynx.

The [machine-readable manifest](docs-routes.json) records exact routes, ownership, status, and scope. [Haddock](https://haddocks.haskell-miso.org/) is an external API lookup, not one of the 41 documentation pages.

## Getting started

| Official page / route | Skill and reference | Use it for |
| --- | --- | --- |
| [Documentation](https://haskell-miso.org/docs/) · `/docs/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/compatibility.md) | Docs entry route; currently serves the introduction content. |
| [Introduction](https://haskell-miso.org/docs/introduction/) · `/docs/introduction/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | Framework scope: virtual DOM, MVU, components, browser and native renderers. |
| [Installation](https://haskell-miso.org/docs/installation/) · `/docs/installation/` | [miso-toolchain](../../miso-toolchain/SKILL.md) · [notes](../../miso-toolchain/references/build-debug.md) | WASM/JS setup, Nix shells, linker/export requirements, and package flags. |
| [Your first Component](https://haskell-miso.org/docs/your-first-component/) · `/docs/your-first-component/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/compatibility.md) | Component type parameters, smart construction, root App, startup, and mount action. |
| [Model–View–Update](https://haskell-miso.org/docs/model-view-update/) · `/docs/model-view-update/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | State transitions feed pure rendering; model equality controls redraw eligibility. |

## Core concepts

| Official page / route | Skill and reference | Use it for |
| --- | --- | --- |
| [The View DSL](https://haskell-miso.org/docs/view-dsl/) · `/docs/view-dsl/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Element namespaces, view tree constructors, and DOM lifecycle references. |
| [Components](https://haskell-miso.org/docs/components/) · `/docs/components/` | [miso-components](../../miso-components/SKILL.md) · [notes](../../miso-components/references/communication.md) | Typed component composition, stable mounting identity, and lifecycle fields. |
| [Text nodes](https://haskell-miso.org/docs/text/) · `/docs/text/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Literal and dynamic text, SSR escaping, raw text caveats, and keyed text. |
| [Fragments](https://haskell-miso.org/docs/fragments/) · `/docs/fragments/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Wrapper-free sibling groups with optional reconciliation keys. |
| [Keys](https://haskell-miso.org/docs/keys/) · `/docs/keys/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Stable identity, fully keyed sibling lists, and intentional component replacement. |
| [Events](https://haskell-miso.org/docs/events/) · `/docs/events/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Delegated event registration, phases, custom decoders, and target references. |
| [Attributes & properties](https://haskell-miso.org/docs/attributes/) · `/docs/attributes/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Typed DOM properties, Boolean values, classes, styles, and element keys. |
| [Effects](https://haskell-miso.org/docs/effects/) · `/docs/effects/` | [miso-effects](../../miso-effects/SKILL.md) · [notes](../../miso-effects/references/effects-data.md) | Pure state changes schedule IO; asynchronous results return through actions. |
| [Context](https://haskell-miso.org/docs/context/) · `/docs/context/` | [miso-components](../../miso-components/SKILL.md) · [notes](../../miso-components/references/communication.md) | Shared application context, seeding, mutation, and explicit repaint subscriptions. |
| [Props](https://haskell-miso.org/docs/props/) · `/docs/props/` | [miso-components](../../miso-components/SKILL.md) · [notes](../../miso-components/references/communication.md) | Read-only parent data, keyed prop mounting, and change notifications. |
| [Communication](https://haskell-miso.org/docs/communication/) · `/docs/communication/` | [miso-components](../../miso-components/SKILL.md) · [notes](../../miso-components/references/communication.md) | Props, context, JSON mailboxes, component targeting, and typed PubSub topics. |
| [Subscriptions](https://haskell-miso.org/docs/subscriptions/) · `/docs/subscriptions/` | [miso-effects](../../miso-effects/SKILL.md) · [notes](../../miso-effects/references/effects-data.md) | Component-lifetime and named subscriptions, sinks, and bracketed resource release. |
| [State & lenses](https://haskell-miso.org/docs/state-and-lenses/) · `/docs/state-and-lenses/` | [miso-effects](../../miso-effects/SKILL.md) · [notes](../../miso-effects/references/effects-data.md) | Model transformations using identity, manual, generic, or generated lenses. |

## Platform

| Official page / route | Skill and reference | Use it for |
| --- | --- | --- |
| [Routing](https://haskell-miso.org/docs/routing/) · `/docs/routing/` | [miso-routing-ssr](../../miso-routing-ssr/SKILL.md) · [notes](../../miso-routing-ssr/references/routing-hydration.md) | Reversible typed routes, captures/query data, history subscriptions, and links. |
| [HTML & prerendering](https://haskell-miso.org/docs/html-and-prerendering/) · `/docs/html-and-prerendering/` | [miso-routing-ssr](../../miso-routing-ssr/SKILL.md) · [notes](../../miso-routing-ssr/references/routing-hydration.md) | Generate route HTML, hydrate matching views, and restore initial model data. |
| [JavaScript EDSL & FFI](https://haskell-miso.org/docs/javascript-edsl/) · `/docs/javascript-edsl/` | [miso-javascript](../../miso-javascript/SKILL.md) · [notes](../../miso-javascript/references/integration.md) | JavaScript globals/properties/methods, safe marshalling, quasiquotes, and FFI wrappers. |
| [Canvas](https://haskell-miso.org/docs/canvas/) · `/docs/canvas/` | [miso-javascript](../../miso-javascript/SKILL.md) · [notes](../../miso-javascript/references/integration.md) | Canvas initialization/drawing callbacks, drawing commands, and frame subscriptions. |
| [MisoString](https://haskell-miso.org/docs/misostring/) · `/docs/misostring/` | [miso-effects](../../miso-effects/SKILL.md) · [notes](../../miso-effects/references/effects-data.md) | Browser/server string representations, formatting, safe parsing, and multiline support. |
| [JSON](https://haskell-miso.org/docs/json/) · `/docs/json/` | [miso-effects](../../miso-effects/SKILL.md) · [notes](../../miso-effects/references/effects-data.md) | Miso JSON values, generic instances, parsing, encoding, and aeson compatibility caveats. |
| [Styles](https://haskell-miso.org/docs/styles/) · `/docs/styles/` | [miso-views](../../miso-views/SKILL.md) · [notes](../../miso-views/references/view-contracts.md) | Structured inline CSS, inline strings, external stylesheets, and development injection. |
| [Development & debugging](https://haskell-miso.org/docs/development/) · `/docs/development/` | [miso-toolchain](../../miso-toolchain/SKILL.md) · [notes](../../miso-toolchain/references/build-debug.md) | Interactive reload, development assets, event diagnostics, and hydration diagnostics. |
| [Internals](https://haskell-miso.org/docs/internals/) · `/docs/internals/` | [miso-toolchain](../../miso-toolchain/SKILL.md) · [notes](../../miso-toolchain/references/build-debug.md) | Queued action batches, scheduler, virtual DOM diffing, and the TypeScript runtime. |

## Native (mobile)

| Official page / route | Skill and reference | Use it for |
| --- | --- | --- |
| [miso native](https://haskell-miso.org/docs/native/overview/) · `/docs/native/overview/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | Lynx target, dual interpreters, native build flags, bundle, and mobile shell. |
| [The dual-thread architecture](https://haskell-miso.org/docs/native/dual-thread/) · `/docs/native/dual-thread/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | First-frame rendering, background diff authority, state replicas, and thread identity. |
| [Static mounting](https://haskell-miso.org/docs/native/static-mounting/) · `/docs/native/static-mounting/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | Static pointer reconstruction, serialized runtime props, and later dynamic mounts. |
| [Effects, subscriptions and threads](https://haskell-miso.org/docs/native/effects-and-threads/) · `/docs/native/effects-and-threads/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | Cross-thread action dispatch and subscription guards for single-owner resources. |
| [Main-thread events](https://haskell-miso.org/docs/native/main-thread-events/) · `/docs/native/main-thread-events/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | Static low-latency handlers, eventual model state, and imperative property ownership. |
| [Main-thread-local state](https://haskell-miso.org/docs/native/main-thread-state/) · `/docs/native/main-thread-state/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | MainThreadRef allocation discipline and frame-coalesced gesture loops. |
| [Platform APIs and thread restrictions](https://haskell-miso.org/docs/native/platform-apis/) · `/docs/native/platform-apis/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | Background-only native modules and main-thread-only element operations. |
| [A minimal native component](https://haskell-miso.org/docs/native/minimal-component/) · `/docs/native/minimal-component/` | [miso-native](../../miso-native/SKILL.md) · [notes](../../miso-native/references/native-contracts.md) | Native counter vocabulary, event setup, and static root entry point. |

## Thinking in Miso

| Official page / route | Skill and reference | Use it for |
| --- | --- | --- |
| [Thinking in miso](https://haskell-miso.org/docs/thinking/overview/) · `/docs/thinking/overview/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | A design workflow from mockup and data to state, views, actions, and composition. |
| [Step 1: Design the model](https://haskell-miso.org/docs/thinking/model/) · `/docs/thinking/model/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | Minimal owned state, computed data, sum types, and meaningful equality. |
| [Step 2: Views and components](https://haskell-miso.org/docs/thinking/components/) · `/docs/thinking/components/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | Plain views by default; isolated components for state and lifecycle ownership. |
| [Step 3: Actions and update](https://haskell-miso.org/docs/thinking/update/) · `/docs/thinking/update/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | Event-oriented action names, total transitions, scheduled IO, and debounce. |
| [Step 4: Connect the pieces and ship](https://haskell-miso.org/docs/thinking/data-flow/) · `/docs/thinking/data-flow/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | Choose scoped communication before connecting routes, prerendering, and platforms. |
| [miso vs. React](https://haskell-miso.org/docs/thinking/miso-vs-react/) · `/docs/thinking/miso-vs-react/` | [miso-thinking](../../miso-thinking/SKILL.md) · [notes](../../miso-thinking/references/design-decisions.md) | Translate hooks into model, update, effects, subscriptions, and lifecycle payloads. |
