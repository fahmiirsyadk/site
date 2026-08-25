---
title: Reconstruct
date: "2026-08-25T18:00:00+07:00"
slug: reconstruct
section: lab
banner: "/assets/banners/reconstruct.jpg"
status: published
tags: ["purescript", "typescript", "foldkit", "effect", "webgl", "architecture"]
ogTitle: "Reconstruct: PureScript, TypeScript, Effect, and Foldkit"
ogDescription: "Why I forked the PureScript optimizer backend to emit TypeScript, map PureScript effects to Effect v4, generate Foldkit bindings, and run this site's browser and WebGL code."
ogImage: "/assets/banners/reconstruct.jpg"
---

I have rebuilt this site three times. It started as a PureScript application using Luna's model-update-view API. I later replaced it with a Haskell static site built with Slick and Lucid. Now it is back in PureScript, targeting TypeScript and running on Foldkit and Effect v4.

Git history still contains each change:

- [`76b6464`](https://github.com/fahmiirsyadk/site/commit/76b6464) introduced the first PureScript site.
- [`1911c4f`](https://github.com/fahmiirsyadk/site/commit/1911c4f) replaced it with Haskell, Slick, and Lucid.
- [`f74025e`](https://github.com/fahmiirsyadk/site/commit/f74025e) brought the application back to PureScript using the first usable `purs-ts` backend.
- [`05f24b2`](https://github.com/fahmiirsyadk/site/commit/05f24b2) removed the remaining application-owned Foldkit bridge and installed the generated `purescript-foldkit` binding.

I kept returning to the same requirement. I wanted the application in a functional language, but I also wanted to call TypeScript libraries and browser APIs directly. PureScript's normal JavaScript output and FFI convention made that combination expensive. I ended up writing a new backend, adding a native Effect runtime profile, and generating the Foldkit bindings.

## Why I returned to PureScript

TypeScript can express immutable data and functional composition, but it leaves those choices to the programmer. A reducer can mutate its input. A discriminated union can widen to a string. Constructing an object can run an effect. Exhaustiveness depends on how carefully every type and branch was written.

PureScript rules out more of those choices. I use algebraic data types to define the states and events the application permits:

```purescript
data Message
  = ClickedInternalLink String
  | ClickedExternalLink String
  | ChangedUrl String
  | LoadedTheme Theme
  | SelectedTheme Theme
  | GotHomeMessage HomeMessage.Message
  | GotPostMessage PostMessage.Message
```

`AppRoute`, `Theme`, page loading status, copy status, and route motion use the same form. A `case` expression matches their constructors. When I add a constructor, the compiler points to incomplete matches before that branch can fail in the browser.

`update` states the whole transition in its type:

```purescript
update :: Model -> Message -> FoldkitUpdate.Return Model Message
```

It receives the current model and a message, then returns a new model with a list of commands. Record update syntax creates that model without changing the previous record:

```purescript
ClickedInternalLink url ->
  result
    (model { routeMotion = Leaving })
    [ NavigateInternal url ]
```

That branch never calls the router. `NavigateInternal` is data, and another function turns it into a Foldkit command backed by an Effect. Keeping the reducer deterministic lets browser runtime tests and Foldkit Scene tests call the same function.

PureScript's function syntax fits how I build components. Functions are curried, partial application is ordinary, and composition appears throughout the application:

```purescript
init: Core.init <<< Core.urlPath

onSuccess:
  AppMessage.GotHomeMessage
    <<< HomeMessage.SucceededLoadGitHub
```

`Core.init <<< Core.urlPath` normalizes a URL before initialization. In `onSuccess`, composition maps a child result into an application message without an intermediate callback. When a value reads better on the left, I use the pipe operator:

```purescript
Document.document
  { title: routeTitle model
  , body: applicationBody model
  }
  # Document.withCanonical (Site.siteUrl <> pathname)
  # Document.withOpenGraphUrl (Site.siteUrl <> pathname)
```

Parametric polymorphism prevents a component from doing work outside its type. This view works for every possible `message`, so it cannot manufacture an application message:

```purescript
view :: forall message. Home.Status -> HH.Child message
```

It can render the supplied status, but it cannot reach into `App.Message` and couple itself to the root. Components that emit events receive the message as an argument. A submodel keeps its child message separate until an explicit function lifts it into the parent message.

Typeclasses let different types share syntax without giving up their own semantics. `PursTs.Effect.Effect error requirements` has `Functor`, `Apply`, `Applicative`, `Bind`, and `Monad` instances, so a sequential Effect v4 program can use PureScript `do` notation:

```purescript
NavigateInternal url ->
  FoldkitCommand.named "NavigateInternal" { url } \_ -> do
    Browser.afterPaint
    reduceMotion <- Browser.prefersReducedMotion
    if reduceMotion then pure unit else Fx.sleepMilliseconds 250
    Browser.pushUrl url
```

Each bind remains inside a typed, lazy Effect value. I can describe the order of the work without `async`, mutable local state, or a Promise chain inside the reducer.

According to the `purescript-effect` documentation, a standard `Effect a` is a value describing a native computation that has yet to run. PureScript values do not perform side effects by default. There is no safe function with the type `forall a. Effect a -> a`: it could return a different result for the same input and break referential transparency. A program composes its effects and eventually hands them to `main`.[^purescript-effect]

`update` can return no commands, one command, or several commands without starting any browser work. Foldkit runs them only after the new model has been produced.

PureScript's compiler recognizes its standard `Effect` monad and can turn a chain of binds into a direct sequential body instead of leaving a tower of dictionary calls in the output. My TypeScript backend keeps that separation between description and execution, then lowers the recognized operations to lazy Effect v4 constructors and combinators instead of JavaScript thunk calls.

## Luna, Lucid, and Foldkit

The first PureScript version used Luna. I started it from Spork's Elm-style client architecture and Halogen VDOM, then developed it as a separate PureScript library for the site. Typed HTML and the `PureApp` and `App` APIs handled the browser application. String rendering, serialized model state, routing, and DOM hydration let the same views run during static generation and again in the browser.[^luna]

Its application followed the familiar model, action, update, and render split:

```purescript
app initialModel =
  { render
  , update
  , subs: const mempty
  , init: purely initialModel
  }

update
  :: Model
  -> Action
  -> Transition (Const Void) Model Action

render :: Model -> Html Action
```

`Html Action` connected the view to the update loop. A click or route input produced an `Action`; `update` returned the next `Model` inside `Transition`; Luna rendered the next virtual DOM tree. Browser integrations could push an action through `inst.pushAndRun`, while subscriptions and effect interpreters were available through the full `App` type. This site used an empty subscription batch and kept routing, scroll tracking, theme changes, and graphics at the browser boundary.

I also extracted a static-site pipeline from Luna. `PrerenderMain` ran under Node, read the generated content manifest, enumerated every route, and called `renderStatic`. Static rendering reused the same `siteLayout` and `renderPage` functions as the client renderer, which kept the server and browser trees structurally identical.

```purescript
render model =
  siteLayout model.route
    (renderPage model.manifest model.route)

renderStatic manifest route =
  siteLayout route
    (renderPage manifest route)
```

Each generated document wrapped that tree in `#app`, serialized a route-specific slice of `SiteManifest` into `__LUNA_INITIAL_MODEL__`, and loaded the browser bundle after the inline state. This slice retained the active article data needed to reproduce the prerendered tree and removed heavy bodies from unrelated posts. Separate files under `/data/posts/<section>/<slug>.json` supplied omitted post content during client navigation.

```text
Markdown content
      |
      v
SiteManifest ---------> renderStatic ---------> route/index.html
      |                                            |
      +-> sliceManifest -> __LUNA_INITIAL_MODEL__  |
                                                   v
Browser bundle -> deserialize model -> hydrate #app -> pushAndRun Action
```

Hydration had a strict requirement: the first client render had to match the existing DOM. Luna's `makeHydrateOrBuild` attached event handlers and application state when it matched. If browser extensions, theme state, or a rendering difference changed the tree, Luna could clear `#app` and build it again. Later versions added an attribute-ignore predicate for browser-extension attributes, patched theme controls before hydration, and deferred WebGL and DOM measurement until after the first paint.

All three implementations kept typed view construction, but they placed state and browser execution in different places:

| Concern | Luna | Lucid | Foldkit |
| --- | --- | --- | --- |
| View type | `Model -> Luna.Html Action` virtual DOM | Haskell functions returning `Lucid.Html ()` | `Model -> Foldkit.Document Message` with generated typed HTML |
| Update model | `Action` enters `update`; `Transition` produces the next `Model` | No persistent client model or update loop in Lucid | `Message` enters `update`; `Foldkit.Update.Return` carries the next model and commands |
| Static output | Node renders the same Luna view used by the client | Slick, Pandoc, and Lucid write complete HTML files | Vite builds the client application; the prerender script currently writes route metadata rather than the body |
| Browser start | Restore serialized route state and hydrate `#app`, with full-render fallback | Load separate scripts for soft navigation, theme, covers, and WebGL | `Runtime.run` starts the Foldkit application and renders the initial model |
| Side effects | `Transition`, interpreters, subscriptions, and browser FFI | Outside Lucid in separate JavaScript | Named commands use native Effect values; mounts use `Scope` for cleanup |

Moving to Haskell removed Luna's persistent browser model and update loop. Lucid built route HTML directly from content and page inputs. Its typed view code looked like this:

```haskell
navLink href label active =
  a_
    [ href_ href
    , class_ (linkClass active)
    ]
    (toHtml label)
```

Foldkit kept nearly the same shape:

```purescript
navLink input =
  HH.a
    [ HP.href input.href
    , HP.class_ (linkClass input.active)
    ]
    [ HH.text input.label ]
```

Lucid builds HTML values with functions but stops at the generated document. Foldkit builds browser HTML through an `HtmlBuilder` and keeps the tree inside a running application. Its `init`, `update`, `view`, commands, URL changes, submodels, and mounted resources return to the Elm-style structure I had with Luna.

Separate JavaScript handled everything that changed after the Haskell build. WebGL lived in a 794-line `gfx/gfx.js`, navigation in `js/spa.js`, cover behavior in `js/cover.js`, and theme changes in `js/theme.js`. Lucid handled the document, while browser behavior sat across another language boundary with no shared `Model` or `Action` type.

Foldkit let me keep the model, messages, updates, and HTML tree in PureScript again. Compared with Luna, it already had the TypeScript runtime and Effect integration I wanted for DOM patching, commands, routing, and mount lifetimes. Compared with Lucid, browser changes returned to the same typed update loop as the view. I still needed PureScript and Foldkit to share runtime values without a handwritten conversion layer.

## Why default PureScript output blocks native TypeScript libraries

PureScript normally compiles to JavaScript. A module with a foreign import gets a JavaScript sibling:

```purescript
foreign import copyPostLink :: String -> Effect Unit
```

```javascript
export const copyPostLink = url => () =>
  navigator.clipboard.writeText(url)
```

PureScript checks the `.purs` signature and expects the provider to follow its runtime ABI. Nothing on the JavaScript side proves that the exported function matches that declaration.

In the standard `purescript-effect` ABI, `Effect a` is a zero-argument JavaScript function. Calling it performs the native work and returns the result. `Effect.Uncurried` can describe an immediately effectful function such as `(level, message) => void`, but `runEffectFn2` converts that function back into the usual curried PureScript form returning an `Effect` thunk. It saves some handwritten nesting. It does not emit TypeScript, import library types, or produce an Effect v4 value.[^purescript-effect-uncurried]

That convention is manageable for a small browser call. It breaks down around TypeScript libraries with their own generic runtime types. Effect v4, for example, uses this type rather than `() => A`:

```typescript
Effect.Effect<A, E, R>
```

Here `A` is the success value, `E` is the typed error, and `R` is the required service environment. Foldkit carries those parameters through commands and mounts. Its HTML API also threads one message type through the builder, properties, children, callbacks, submodels, and documents.

Putting a declaration file beside generated JavaScript cannot change its ABI. I still had to resolve these mismatches:

| PureScript source | Normal JavaScript ABI | Desired TypeScript API |
| --- | --- | --- |
| `a -> b -> c` | `a => b => c` | `(a, b) => c` at exported boundaries |
| `Effect a` | `() => a` | `Effect.Effect<a, e, r>` |
| `data Message = ...` | backend-specific constructors | discriminated union with `_tag` |
| `newtype UserId = UserId String` | erased value | erased TypeScript alias with the correct public type |
| `foreign import` | `foreign.js` | checked `foreign.ts` or a package export |

PureScript calls must remain curried internally because that is the language's evaluation model. TypeScript callers usually expect one multi-argument call when every argument is available. Generated modules therefore need a curried internal binding and an uncurried public wrapper.

ADTs have a similar constraint. PureScript's JavaScript backend has historically emitted constructor objects or classes, while another backend may choose tagged records. Foldkit expects structural messages with a stable discriminator. Generated constructors, pattern matches, public types, and the Foldkit runtime must all agree on that representation.

FFI can bridge normal PureScript output to Effect and Foldkit, but doing it across this site meant repeating too much of both libraries by hand.

## What `ts-bridge` solved, and what it could not solve

Before forking the backend, I tried `purescript-ts-bridge`. Version 4 generates TypeScript declarations through a user-defined PureScript typeclass. You define instances for supported types, choose the exported values, create a type-generation CLI, and run it as a separate build step.[^ts-bridge]

This works when TypeScript needs declarations for JavaScript that PureScript has already compiled. It does not produce executable TypeScript; the normal PureScript output still provides the runtime code.

Its documented ABI matches the standard PureScript JavaScript backend, not the ABI I needed:

- functions are generated as curried TypeScript functions;
- `Effect a` is generated as `() => A`;
- ADTs such as `Maybe` and `Either` are opaque branded types;
- constructors and destructor functions must be exported manually to use those ADTs from TypeScript;
- uncurried functions were listed as future work in the version used by the site.[^ts-bridge-types]

That model cannot describe Foldkit's structural message union or Effect v4's error and requirements parameters. It also cannot import a TypeScript library's declarations into PureScript.

To make it usable, I added another layer around the generated declarations. `Bridge.Generate` and `Bridge.Wire` selected exports for `ts-bridge`. My first direct-output migration removed those modules and the `generate:types` build step, but Foldkit still depended on handwritten application interop.

That handwritten Foldkit bridge contained a local HTML algebra:

```purescript
data Prop message
  = Attribute String String
  | InnerHtml String
  | OnClick message
  | OnMouseEnter message
  | OnMouseLeave message
  | OnMount (MountAction message)

data Child message
  = Empty
  | Text String
  | Element
      { tag :: String
      , key :: Maybe String
      , attributes :: Array (Prop message)
      , children :: Array (Child message)
      }
```

`Interop.Foldkit.Html` listed every tag used by the site. `Interop.Foldkit.Prop` supplied a generic string attribute and a few events. Every new `disabled`, `aria-checked`, `onInput`, keyboard, SVG, or media property meant adding a PureScript constructor and a renderer branch, often followed by another TypeScript function.

Worse was the message boundary. `App.Wire.Message` encoded every application constructor as one record containing every possible field:

```purescript
type RawFields =
  { _tag :: String
  , requestTag :: String
  , requestUrl :: String
  , requestHref :: String
  , url :: String
  , theme :: String
  , contributions :: Int
  , followers :: Int
  , levels :: Array Int
  }
```

Unused fields became empty strings, zeros, or empty arrays. Another function decoded the record back into `App.Message`, while a separate array listed the accepted tags. I now had the same ADT in its PureScript definition, a raw record, and TypeScript runtime code.

By commit `f74025e`, this approach had added 150 lines to `Interop.Foldkit.purs`, 76 lines of hand-listed elements, 271 lines to the Foldkit command adapter, and 246 lines for the message wire module. It ran the site, but declarations alone had not removed the interop layer.

## Forking `purescript-backend-optimizer`

I based the TypeScript backend on `purescript-backend-optimizer`, which already handled the difficult compiler work:

- a CoreFn JSON model;
- conversion from CoreFn into a backend-neutral optimizer IR;
- effect analysis and foreign semantics;
- reachability and module building;
- optimized pattern matching;
- tail-call handling and inlining.

Spago and `purs` already produce CoreFn for values and `docs.json` for public types, so the fork did not need another parser. I could reuse the optimizer pipeline and add a TypeScript AST, type reconstruction, lowering rules, and a printer.

I set six rules in the first design, and they still hold:

1. CoreFn is converted through the optimizer IR instead of lowered directly.
2. Internal PureScript function application stays curried.
3. Exported functions with known arity receive uncurried TypeScript wrappers.
4. `docs.json` supplies source-level type declarations because CoreFn is primarily a runtime representation.
5. Output uses `.ts`, ESM, and explicit `.ts` imports.
6. Every stage must pass `tsc --strict` and execute a focused fixture.

Printing a different file extension was the small part. Most of the work went into preserving PureScript semantics while defining a public TypeScript ABI.

## A 35-stage implementation path

I split the backend work into small acceptance stages. Each one added a runtime or type boundary while keeping the earlier fixtures running.

| Stages | Work completed |
| --- | --- |
| 0-5 | Primitive values, records, arrays, TypeScript AST and printer, cross-module imports, ADTs, newtype erasure, parameterized ADTs, and a message-envelope fixture |
| 6-9 | Native `Effect` thunks, Node FFI, cross-module FFI, and generated adapters between curried raw providers and uncurried TypeScript exports |
| 10-14 | Effect v4 runtime profile, lazy Promise conversion, typed errors, Effect composition, and a narrow `ExceptT e Effect a` boundary |
| 15-20 | Real-site type coverage, constructor compatibility, browser execution, Vite integration, production build, and the first direct-output site branch |
| 21-24 | Manifest-owned output, generated-text caching, wider FFI types, dependency graphs, capability metadata, and explicit build roots |
| 25-29 | Native-profile `Aff`, callback and `FnN` coverage, centralized runtime capabilities, better type fidelity, and PureScript-owned runtime templates |
| 30-31 | Removal of dead type imports, aliases, internal bindings, phantom parameters, and unused lambda parameters |
| 32-35 | Tagged-record ADTs, direct package providers, native three-parameter Effect values, package-owned PureScript sources, automatic roots, transactional output, and the Vite development frontend |

Stage 15 was the first run against the real site. Only 10 of 39 selected targets generated and passed strict TypeScript. Most failures came from compiler data flow. A type used only in an exported signature disappeared after the optimizer removed its runtime import. One unsupported `Data.Array` declaration caused the backend to reject an entire `docs.json`. Foldkit's `FnN` types and higher-kinded declarations also needed explicit mappings.

I separated runtime reachability from type reachability, tracked unsupported documentation nodes per declaration, and retained type-only imports. Errors now appeared only when a required declaration could not be translated. With those changes, the Stage 15 probe passed 40 of 40 targets. Later stages replaced the disposable site copy with the site's own `pnpm build`, Vite plugins, metadata prerenderer, and browser runtime.

I also removed the temporary consumer configuration as the build frontend took over its work. Roots files, repeated `--module` arguments, Spago alternate-backend YAML, entry shims, and compiler wrapper scripts helped test individual boundaries, but none remains in the application contract.

## How `purs-ts build` works now

Today `purs-ts build` owns the complete PureScript-to-TypeScript build:

```text
package.json + spago.yaml
        │
        ├─ discover project and dependency PureScript sources
        ├─ discover binding packages from direct dependencies
        ├─ include binding-owned and backend-owned .purs modules
        ▼
invoke Spago / purs for CoreFn and docs
        │
        ▼
CoreFn JSON ──→ optimizer IR ──→ TypeScript expression AST
docs.json   ──→ type environment ──→ TypeScript type AST
        │
        ├─ resolve TypeScript FFI providers
        ├─ resolve direct package providers
        ├─ generate runtime facade and optional entry.ts
        ▼
staged output tree ──→ project tsc --noEmit ──→ atomic promotion
```

Discovery starts with direct `dependencies`, `devDependencies`, and `optionalDependencies`. Binding metadata can refer to another binding. Missing packages, multiple versions, duplicate module ownership, incompatible runtime profiles, or competing entry runners stop the build with an error.

It also finds the application `main` and TypeScript host imports such as `purescript/Runtime.Canvas/index.ts`. Functions referenced only by a WebGL provider still enter the generated graph, without a roots file in the site repository.

Before replacing `output/`, the frontend writes a candidate tree beside it. An ownership manifest identifies stale generated files and leaves user-owned files alone. TypeScript checks the candidate using the project's compiler; if that check fails, the previous output stays in place and Vite never sees a partial graph.

`purs-ts dev` builds once, starts the project's installed Vite server, then watches `.purs` files and the `.ts` siblings of FFI modules. Compile errors do not kill Vite, so the next edit can repair the graph.

## Generated TypeScript ABI

Structural records and arrays cross into TypeScript without serialization. ADTs, functions, effects, and opaque values need an explicit representation.

With the site's `taggedRecord` profile, constructors become discriminated TypeScript records:

```typescript
export type Message =
  | { "_tag": "ClickedInternalLink"; "_1": string }
  | { "_tag": "ChangedUrl"; "_1": string }
  | { "_tag": "CompletedMountSeaShader" }
  | { "_tag": "GotHomeMessage"; "_1": HomeMessage }
```

Generated pattern matches inspect `_tag`; positional constructor fields use `_1`, `_2`, and so on. A constructor with one record argument can flatten its fields beside `_tag`. PureScript modules, TypeScript providers, and Foldkit all receive that same value.

Newtypes erase to their runtime value, and records become structural object types. PureScript `Int` appears as TypeScript `number`, with generated arithmetic preserving signed 32-bit behavior where PureScript requires it. A higher-kinded value that has no sound TypeScript representation gets either a named `unknown` boundary or a specific unsupported-type error, never an automatic `any`.

A foreign module may have a `.ts` sibling in the application:

```text
src/Platform/Browser.purs
src/Platform/Browser.ts
```

During a build, the provider is copied to `output/Platform.Browser/foreign.ts`. Its relative imports are rewritten for the new location, and its named exports are checked against the PureScript declarations. Package bindings can map a module directly to an export such as `purescript-foldkit/runtime`, which avoids generating a local FFI file.

Before TypeScript checks the graph, code generation removes unused `Maybe` aliases, dead namespace imports, unreachable `$internal` bindings, unused lambda arguments, and phantom generics. I also run Oxlint's `no-unused-vars` rule against a non-ignored copy of `output/`.

## Mapping PureScript syntax to Effect v4

Before writing the Effect runtime, I reviewed `effect@4.0.0-rc.111` at official repository commit [`993f4be`](https://github.com/Effect-TS/effect/commit/993f4be99949d4682f79c22b9cb8dc2fda37ec7c). I wanted the backend tied to the installed v4 release candidate, not to remembered v3 APIs or whatever happened to be on `main` later.

That source defines:

```typescript
Effect<A, E = never, R = never>
```

Standard PureScript starts with the one-parameter type from `purescript-effect`:

```purescript
Effect.Effect value
```

My backend still supports that type. Its native profile keeps the documented thunk representation, `() => value`; its Effect profile lowers the same source type to `Effect.Effect<value, never, never>`. Those two `never` arguments are deliberate. A standard `Effect value` has nowhere to state a recoverable error or a required service, so generated TypeScript must not invent either one. Existing JavaScript FFI thunks pass through `Effect.sync` exactly once.

That one parameter is not enough for this site. A GitHub request has a recoverable error channel. A WebGL mount requires `Scope`, which keeps its release action registered until Foldkit unmounts the element. I added a separate intrinsic type for those cases.

Its parameters follow the order used by the PureScript API:

```purescript
foreign import data Effect
  :: Type  -- error
  -> Type  -- requirements
  -> Type  -- value
  -> Type
```

Code generation reverses them into Effect v4's order:

```text
PursTs.Effect.Effect error requirements value
    ↓
Effect.Effect<value, error, requirements>
```

`PursTs.Effect` ships in the backend archive, and `purs-ts build` includes it automatically. For now, requirements are limited to `NoServices` and `Scope`, which cover browser commands and resource mounts. Arbitrary service unions are still outside the implemented type model.

A foreign import's result type selects its ABI. Standard `Effect.Effect value` follows the legacy thunk contract. `PursTs.Effect error requirements value` requires its TypeScript provider to return a native Effect v4 value. Selection happens during compilation, with no runtime inspection and no per-binding YAML flag.

`PursTs.Effect` exposes `succeed`, `fail`, `sync`, `suspend`, `map`, `flatMap`, `as`, `mapError`, `catchAll`, `match`, `acquireRelease`, sleep, sequential `zip`, and parallel `zipPar`. Its typeclass instances are sequential; parallel execution must be requested with `zipPar`.

`Effect.succeed(value)` receives a value that has already been evaluated, while PureScript's effect form evaluates its value when the effect runs. To preserve that timing, the backend lowers a pure effect through suspension:

```typescript
Effect.suspend(() => Effect.succeed(value))
```

Direct foreign providers follow the same rule. `Platform.Browser.ts` returns a native Effect value:

```typescript
export const resetScroll =
  Effect.try(() => {
    document.getElementById('content-scroll')?.scrollTo({ top: 0, behavior: 'auto' })
    window.scrollTo({ top: 0, behavior: 'auto' })
  })
```

Code generation suspends the call itself:

```typescript
export const copyPostLink = (url: string) =>
  $effectRuntime.suspend(() => $foreign.copyPostLink(url))
```

Constructing this command during `update` cannot start its Promise or throw from provider construction. Foldkit starts it when the command runs. Promise rejections enter Effect's typed error channel, and interruption reaches the `AbortSignal` from `Effect.tryPromise` when the provider supports cancellation.

Application commands convert both expected outcomes into messages:

```purescript
LoadGitHub username ->
  FoldkitCommand.named "LoadGitHub" { username } \_ ->
    Fx.match (Browser.loadGitHub username)
      { onFailure: const (GotHomeMessage FailedLoadGitHub)
      , onSuccess: GotHomeMessage <<< SucceededLoadGitHub
      }
```

Foldkit receives `Command Message`, so it never has to invent a policy for a domain error.

Mounts use the requirements parameter for resource lifetime. `Effect.acquireRelease` returns an Effect requiring `Scope`, and closing that scope runs the release action. Foldkit's binding keeps the requirement in its type:

```purescript
define
  :: String
  -> (Element -> Fx.Effect Fx.Never Fx.Scope message)
  -> MountAction message
```

Site mounts acquire a browser cleanup callback, register `Browser.release`, and return a result message. Foldkit keeps the scope open while the element remains mounted. Removing the element closes it and runs the cleanup.

## Generating `purescript-foldkit`

After the direct TypeScript output worked, the handwritten Foldkit bridge was the largest inconsistency left in the application. I moved that integration into a package built from Foldkit's own declarations.

`purescript-foldkit` contains the reusable PureScript API, small TypeScript providers, their declarations, and generated package metadata. Its generator reads Foldkit 0.151.0, then hashes the declarations for HTML, commands, mounts, navigation, runtime, and URLs. From that input it writes:

- the complete `Foldkit.Html` element module;
- the complete `Foldkit.Html.Prop` property module;
- `purs-ts.bindings.json`, which describes every package-owned PureScript source, direct provider, runtime requirement, the entry runner, generated export, and upstream hash.

Commands, mounts, runtime conversion, documents, submodels, and update helpers now live once in the binding package. Applications install them instead of copying them. Generation is reserved for the large surfaces that follow Foldkit's declarations and for the metadata that records the exact upstream input.

Parsing the complete `HtmlElements<Message>` and `HtmlAttributes<Message>` declarations currently produces 212 HTML, SVG, and MathML elements plus 307 properties.

Every TypeScript property shape passes through a fixed mapping. Strings become `String`, booleans become `Boolean`, numbers become `Number`, and arrays recurse through the same mapping. Message values retain the `message` parameter; callbacks become curried PureScript functions; optional messages become `Maybe`; files and elements stay opaque; mount actions retain their message type. Explicit cases cover `aria-checked`, keyboard modifiers, style records, data attributes, and multi-argument properties.

An unsupported type, callback arity, declaration, or normalized-name collision stops generation. New Foldkit types never degrade silently to `Foreign`. A fixed rename table handles PureScript keywords, including `class_`, `for_`, `role_`, `type_`, and `innerHtml`.

Public HTML values use renderer newtypes:

```purescript
newtype Prop message =
  Prop (HtmlBuilder message -> RenderedProp message)

newtype Child message =
  Child (HtmlBuilder message -> RenderedChild message)
```

Each generated property closes over its typed value and selects the matching Foldkit builder function inside the binding. Elements render those property and child functions with the builder they receive. Components never store a giant `Prop` constructor union or pass `HtmlBuilder` through their inputs.

Site code uses the generated API directly:

```purescript
HH.canvas
  [ HP.id "sea-canvas"
  , HP.class_ "block w-full touch-none"
  , HP.onMount { action: Mount.seaShader }
  ]
  []
```

`purs-ts.bindings.json` records the exact Foldkit version and the SHA-256 of every declaration file used as input. If the installed version or a declaration hash differs, `purs-ts build` fails and asks for regeneration. It will not run an old binding against a different library build.

Commands, mounts, submodels, URL normalization, document construction, and update helpers also belong to the package. Most of `Foldkit.Update` is PureScript because it only transforms models and command arrays. Runtime calls are isolated in the small `Foldkit.Raw.*` TypeScript boundary.

## Site application architecture

Five functions define the application root:

```purescript
main = Runtime.run
  { init: Core.init <<< Core.urlPath
  , update: Core.update
  , view: View.view
  , onUrlRequest: Core.clickedLink
  , onUrlChange: Core.changedUrl
  }
```

`App.Model` contains the route, theme, route transition, home model, and post model. Each page owns its messages, model, update, commands, and view. At the boundary, `GotHomeMessage` and `GotPostMessage` wrap child messages for the parent. `Foldkit.Submodel` performs that mapping without exposing the HTML builder.

`App.Update` contains state transitions and command descriptions. `App.Command` turns those descriptions into named Foldkit commands, retaining their names and arguments for Scene tests and devtools. `Fx.match` or `Fx.catchAll` converts expected failures into application messages.

`App.View` returns a typed `Document Message`, with routes selecting page views through `case`. It creates canvases and associates them with mount actions without calling WebGL itself. Once the required title and body exist, document modifiers add the canonical and Open Graph URLs.

`Platform.Browser.purs` now contains only site capabilities: clipboard access,
GitHub requests, route-specific metadata, scroll behavior, and WebGL resource
acquisition. Foldkit owns the reusable browser primitives in
`Foldkit.Navigation`, `Foldkit.Render`, `Foldkit.Media`, `Foldkit.Storage`,
and `Foldkit.Root`. `App.Command` composes those primitives with the site's
messages and policies. The remaining TypeScript FFI is therefore domain code,
not a second copy of the Foldkit runtime.

## Pure calculations and WebGL execution

Graphics use the same split. PureScript owns calculations and state transitions; TypeScript owns WebGL objects, DOM events, observers, image loading, and animation frames. Vite imports the GLSL from separate `.vert` and `.frag` files.

### Shared raster and frame calculations

`Runtime.Canvas.rasterLayout` converts CSS dimensions and device pixel ratio into canvas dimensions. Callers set their own minimum and maximum pixel ratios. This lets the header mark render at a higher density while the full-width sea shader caps its cost.

`Runtime.Frame.frameTiming` computes seconds since mount and derives the intro progress. It also clamps long frame deltas to 40 ms, preventing a background-tab pause from causing a large motion jump on resume.

### Sea footer

`Runtime.SeaMotion` holds the drag target, smoothed position, previous position, velocity, and lab-hover interpolation. PureScript converts pointer input into a bounded target, then applies smoothing and damping on each frame.

`platform/browser/shader.ts` creates the WebGL2 context and shader program, then writes PureScript state into uniforms for cube offset, velocity, time, theme, intro, cloud quality, and hover. A `ResizeObserver` updates the viewport, while an `IntersectionObserver` stops animation outside the visible area. Cleanup cancels the frame, disconnects both observers, removes pointer listeners, deletes the vertex array and shader program, and releases the context.

### Hollow mark

`Runtime.HollowGeometry` generates the split sphere and cube mesh. Drag angle, angular velocity, smoothing, inertia, snapping, and reduced-motion behavior live in `Runtime.HollowMotion`.

`hollow-mark.ts` uploads the mesh, loads `lroc-color-1k.webp` into a moon texture, and forwards motion values to the shader. TypeScript handles pointer capture because it is a browser API; PureScript handles the angle calculation and state transition. Cleanup removes listeners, observers, the buffer, texture, shaders, pending image handler, animation frame, and WebGL context.

### Dithered Markdown images

`Runtime.Dither` parses the CSS ink color, stores the 4×4 Bayer matrix, calculates aspect-preserving texture coordinates, and decides whether reduced-motion settings allow another frame.

`dithered-image.ts` uploads the source image and Bayer matrix as textures. Its shader uses the current theme's ink color for the dithered result. If WebGL initialization or shader compilation fails, the original image remains visible; a `webglcontextlost` handler restores the same fallback.

Client-side navigation replaces article HTML inside an existing container. A `MutationObserver` watches for inserted and removed dither roots, mounting new canvases and releasing detached ones. Browsers limit live WebGL contexts, and an article may contain several images, so each detached canvas must release its context.

### Random scribble

`Runtime.Scribble` stores path variants, prevents the same path from being selected twice, and builds the keyframe description. Its TypeScript provider handles randomness, DOM selection, path measurement, and the Web Animations API. Selection rules and animation plans stay in testable PureScript code.

## Content and production output

During the Vite build, the content plugin parses frontmatter and renders Markdown to HTML. MarkdownIt never enters the browser bundle, and `Content.Repository` receives only posts marked `status: published`.

`Domain.Content` handles ordering, section filtering, lookup, neighboring posts, and metadata fallback. Using its generated TypeScript module, the prerender script writes route-specific title, canonical, Open Graph, and Twitter metadata, along with `sitemap.xml` and `robots.txt`.

This remains a client-rendered SPA. Prerendering gives each public path the correct document metadata before the runtime starts. Later route changes run `SyncDocumentMetadata` and apply the same policy in the browser.

## Distribution and verification

Neither package is published to npm yet. I distribute the backend and Foldkit binding as local pre-release archives:

```text
vendor/purs-backend-ts-0.1.0.tgz
vendor/purescript-foldkit-0.1.0.tgz
```

Before each site build, a script checks the archives against their SHA-256 files. Another repository can install and test them without npm publication or a sibling source checkout. One archive contains the `purs-ts` executable and intrinsic PureScript sources. Its Foldkit counterpart packs the PureScript modules, TypeScript providers, declarations, and generated binding sidecar.

No backend arguments appear in the site's `spago.yaml`. Development and production use the normal package commands:

```bash
pnpm check
pnpm lint
pnpm build
pnpm dev
```

`pnpm check` verifies archive metadata and checksums, validates TypeScript FFI providers, compiles through `purs-ts`, checks generated output with strict TypeScript, and runs the Vitest and Foldkit Scene suites. `pnpm build` performs the same PureScript build before Vite bundles the application and prerenders metadata.

Some boundaries remain deliberately narrow. Effect requirements support `NoServices` and `Scope`, but not arbitrary services. Generic PureScript ADTs do not yet generate field-level Effect Schemas for untrusted remote input. Foldkit subscriptions, arbitrary streams, and interruptible commands still need lifecycle work. Cross-machine release testing and npm publication are also pending.

A new PureScript repository needs the two checksummed archives, ordinary Spago dependencies, a strict `tsconfig.json`, and three commands:

```bash
pnpm install
pnpm exec purs-ts build
pnpm exec purs-ts dev
```

[^ts-bridge]: [`purescript-ts-bridge` v4 README and getting-started guide](https://github.com/m-bock/purescript-ts-bridge/tree/v4.0.0) describe the typeclass-driven `.d.ts` generator and separate CLI entry point.

[^ts-bridge-types]: The [`purescript-ts-bridge` v4 type comparison](https://github.com/m-bock/purescript-ts-bridge/blob/v4.0.0/docs/type-comparison.md) and [FAQ](https://github.com/m-bock/purescript-ts-bridge/blob/v4.0.0/docs/faq.md) document opaque ADTs, manual constructor/destructor exports, curried functions, and `Effect a` as a zero-argument TypeScript function.

[^purescript-effect]: The [`purescript-effect` 4.0.0 documentation](https://github.com/purescript/purescript-effect/tree/v4.0.0) describes `Effect a` as a value representing a native computation, explains why it does not compromise purity, and documents the compiler's special treatment of Effect binds.

[^purescript-effect-uncurried]: [`Effect.Uncurried`](https://pursuit.purescript.org/packages/purescript-effect/4.0.0/docs/Effect.Uncurried) documents the conversion between uncurried immediately effectful JavaScript functions and curried PureScript functions returning `Effect`.

[^luna]: [`fahmiirsyadk/luna` at the revision used by the final PureScript version](https://github.com/fahmiirsyadk/luna/tree/a24c61e434ac0f5ce4e5e67412cfc86509b5a985) documents its Spork and Halogen VDOM roots, Elm-style application API, string rendering, model serialization, routing, SSG, and hydration support.
