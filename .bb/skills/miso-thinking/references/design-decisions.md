# Design decisions

Use this reference when choosing a state shape or reviewing an architecture.

For a searchable product screen, the parent can own fetched products, the query, a category filter, and the selected product ID. Derive visible products and category counts. A private add-product draft belongs in a child component if it has its own validation and submission lifecycle. Sharing the current category with that form requires props; sending a validated submission back requires mail or a parent-owned action, depending on whether the form is a component or view function.

Choose `NotAsked | Loading | Failed Error | Loaded a` when these are exclusive states. Add a refreshing state only when the product actually keeps previous results visible during refresh. Avoid adding a parallel boolean for every rendered label.

A view function can accept data and action constructors without owning another MVU loop. A component has its own model and action vocabulary. Repeated visual boxes alone do not require repeated state machines.

When migrating React code, map state cells to model fields, reducers to update branches, DOM refs to lifecycle action payloads, and ongoing event sources to subscriptions. Miso's `Effect` schedules work in response to actions; it is not a hook with dependencies. Props and context retain their ownership meanings, but context repainting requires explicit opt-in.

Review questions:

- Can two fields disagree because one duplicates a computed value?
- Does the component boundary isolate behavior or only split markup?
- Does every external result become an action with an error path?
- Are component/list identities stable through insertions and filtering?
- Can the initial URL and server data recreate the same first view?

Sources: [model design](https://haskell-miso.org/docs/thinking/model/), [views and components](https://haskell-miso.org/docs/thinking/components/), [data flow](https://haskell-miso.org/docs/thinking/data-flow/), [React comparison](https://haskell-miso.org/docs/thinking/miso-vs-react/).
