# View contracts

| Concern | Implementation rule | Source |
| --- | --- | --- |
| Elements | Use `H.*_`; use `node` with the correct namespace only for missing elements. SVG and MathML have their own modules. | [View DSL](https://haskell-miso.org/docs/view-dsl/) |
| Text | Literals work with `OverloadedStrings`; dynamic content uses `text`. Keep user content escaped when rendering HTML. `text_` inserts spaces between strings. | [Text](https://haskell-miso.org/docs/text/) |
| Fragments | `vfrag`/`fragment` group siblings without wrapper markup; `vfrag_`/`fragment_` attach group identity. | [Fragments](https://haskell-miso.org/docs/fragments/) |
| Identity | `key_` belongs to the repeated outer element; `(+>)` keys child components. Include stable keys on all siblings for the keyed-list optimization. | [Keys](https://haskell-miso.org/docs/keys/) |
| Properties | Prefer `value_`, `class_`, `classList_`, and typed `Miso.Property` helpers. For conditional booleans, use `boolProp` with a Boolean rather than the string `"false"`. | [Attributes](https://haskell-miso.org/docs/attributes/) |
| Events | `defaultEvents` omits keyboard, pointer, and touch families. Add the used families to the startup event map. `*With` handlers can supply the target reference. | [Events](https://haskell-miso.org/docs/events/) |
| Custom decoding | Choose the event payload path with `DecodeTarget`, parse only required fields, and match the current handler signature. Do not assume React synthetic-event APIs. | [Events](https://haskell-miso.org/docs/events/) |
| CSS | Qualify `Miso.CSS`; use `CSS.style_` for structured properties or the existing external stylesheet. Component `styles`/`scripts` injection is a development convenience. | [Styles](https://haskell-miso.org/docs/styles/) |

For DOM widgets, initialize after `onCreatedWith` dispatches a reference. Choose destruction hooks according to whether cleanup needs the element still attached; check timing in the pinned source. Keep library-managed descendants isolated from Miso-managed children.

Accessibility is a UI implementation concern, and discoverable class literals matter when a CSS scanner such as Tailwind is used. Neither requires an additional Miso API or dictates a project's CSS strategy.
