# Direct purs-ts output

This branch uses the TypeScript backend as the application boundary:

```text
PureScript source + installed binding packages
      │ purs-ts (Spago source discovery + purs)
      ▼
CoreFn/docs in .purs-ts/corefn/
      │ purs-ts backend
      ▼
generated TypeScript in output/**/*.ts
      │ Vite / Node
      ▼
browser application
```

The generated TypeScript is the application-facing API. Public functions are
exported with TypeScript-callable signatures, generated relative
imports use `.ts`, and the Effect runtime is emitted as `effect-runtime.ts`.
The generated `output/entry.ts` imports `App.Entry` and executes its Effect with
the generated runtime. `index.html` references this generated entry directly.
The generated-output Oxlint worklist is tracked in
[`docs/oxlint-backend-followups.md`](./oxlint-backend-followups.md).

## What was removed

The old declaration bridge is no longer part of the build:

- `ts-bridge` was removed from `spago.yaml`.
- `src/Bridge/Generate.purs` and `src/Bridge/Wire.purs` were removed.
- `generate:types` is no longer a build step.
- TypeScript consumers import generated modules from `output/` directly.
- The site-owned `Interop.Foldkit`, `Html`, `Prop`, and generic HTML provider
  were replaced by the `purescript-foldkit` binding package.
- The site-owned compiler wrapper, Vite compiler plugin, roots generator,
  `.purs-ts-roots`, and `src/entry.ts` were removed.

The `purs-ts` command invokes Spago source discovery, compiles CoreFn/docs,
discovers installed binding sidecars and TypeScript host imports, runs the
backend, generates the entry, promotes `output/` atomically, and runs strict
TypeScript validation. Neither `spago.yaml` nor site scripts configure the
backend. Both packages come from checksummed tarballs under `vendor/`.

## TypeScript FFI boundary

Removing the Bridge does not remove platform FFI. FFI is still the appropriate
boundary for operations supplied by TypeScript or the browser platform,
including DOM, WebGL, Foldkit constructors and commands, and content/build
adapters. Site-owned providers are `.ts` siblings of their `.purs` modules.
The backend prefers those providers and emits them as `foreign.ts`.

Dependencies that only ship traditional PureScript `.js` providers remain a
backend compatibility concern. Site-owned FFI and reusable bindings are `.ts`,
and generated `index.ts` modules never import or re-export `foreign.js`.

The policy is therefore:

```text
PureScript application logic  → generated .ts
PureScript Effect operations  → generated Effect v4 code
Browser/platform primitives   → small TypeScript FFI providers
TypeScript application glue   → direct imports of generated .ts
```

Site FFI providers must not recreate the old Bridge API. They expose only the
native operation required by the PureScript declaration and return native
`PursTs.Effect` values where effects are involved. Foldkit receives the
generated application message ADT directly. `Runtime.Scribble` owns selection
and the animation plan; remaining browser TypeScript executes DOM, WebGL, Vite
content-loading, randomness, and observer APIs.

Use this ownership test before adding browser TypeScript:

| Concern | Owner |
| --- | --- |
| state, decisions, data transforms, application messages, animation plans | `.purs` |
| DOM/WebGL calls, events/observers, Vite loaders, external library calls | `.ts` FFI/platform adapter |
| generated application/runtime modules | `output/**/*.ts` (never edit) |

### Codegen constraints for Effect-heavy PureScript

The backend's generated TypeScript is validated with `tsc --noEmit`, and
empirical probing (2026-08-29, while moving the four WebGL mounts into
PureScript) found these rules for modules that pass validation:

- **Foreign imports must be on the module export list to get a real type.**
  Type information is decoded from purs `docs.json`, which only contains
  declarations on the export list. An unexported foreign import degrades to
  `$runtime.Dynamic` and cascades `TS2345` mismatches through every caller.
  Same for referenced types: export `DitherUniforms` if an exported foreign
  import mentions it.
- **Curry foreign imports.** A curried declaration `(a) -> (b) -> Effect c`
  keeps full types; `Fn2`/`Uncurried` forms fall back to `Dynamic`.
- **No self-recursive functions.** They emit recursive `const`s without
  annotations and fail with `TS7023`/`TS7024`. Break cycles through a mutable
  cell read at invocation time (see `resumeScribbleChain`).
- **No class-dictionary combinators in Effect chains.** `Data.Foldable`'s
  `traverse_` generates as `(...): unknown` and poisons the chain. Use a plain
  `forEach` foreign primitive instead.
- **Do-blocks of roughly 12+ binds hang the `_backend` codegen process.**
  Split mount bodies into small named helpers (~8 binds each) threading a
  context record.
- **TypeScript siblings must match mutability exactly.** A PS `Array a`
  generates `a[]` (mutable); a sibling typed `ReadonlyArray<a>` fails the
  foreign-import conversion with `TS2352`.
- **`?raw` asset imports are not path-rewritten in the copied `foreign.ts`.**
  Relative `.ts` imports are rewritten back to `src/`, but `?raw` imports are
  copied verbatim and break at their new location. Route shader sources
  through a plain TypeScript module (`Platform/Browser/Shaders.ts`).

## Current commands

From the site checkout:

```bash
pnpm check:backend
pnpm check:ffi
pnpm build:ps
pnpm check:generated
pnpm exec tsc --noEmit
pnpm test
pnpm build
pnpm dev
```

`build:ps` is `purs-ts build`. It discovers one `main` entry plus every
`purescript/<Module>/index.ts` import in project TypeScript, so tests and browser
adapters retain their public PureScript exports without a roots manifest.
`check:generated` fails if a required host root is missing, any `.js` artifact
exists, or generated TypeScript imports JavaScript. `pnpm build` adds the Vite
production bundle and metadata prerender. `pnpm dev` is `purs-ts dev`: the
backend performs the initial build, starts Vite, watches `.purs` and sibling FFI
`.ts` files, and rebuilds atomically.

Agents should use the command contract documented in `AGENTS.md`. A successful
compile prints `purs-ts built App.Entry` followed by binding-package and
TypeScript-host-root counts. `spago.yaml` containing `workspace.backend` is a
configuration error.

## Migration rating

The application migration is **9.8/10**. Application and platform FFI are
TypeScript-only at runtime, the Bridge and generic local Foldkit bridge are
gone, build/dev orchestration is backend-owned, runtime behavior and application
messages remain PureScript-owned, TypeScript host roots are automatic, the
generated-output contract passes, the full Foldkit element/property DSL is
declaration-generated, and regression checks enforce the boundary. The generated
TypeScript still has the backend follow-ups recorded in
`docs/oxlint-backend-followups.md`.
Both local `0.1.0` packages are checksummed and installation-tested. The
remaining 0.2 is feature breadth:
more external libraries should move to package-owned typed bindings and broader
CoreFn/library coverage still needs fixtures. Cross-machine CI and publication
are intentionally outside the current feature/output-generation stage.

## Verified evidence

On 2026-08-25 with Node 26.4.0:

- FFI validation checks site-owned PureScript files and requires `.ts` siblings for
  every module with value-level foreign imports.
- `purs-ts` built `App.Entry` with 1 binding package and automatically
  discovered TypeScript host roots.
- Strict TypeScript checking passed with `tsc --noEmit`.
- Vitest, strict TypeScript, Vite production bundling, and metadata prerender pass.
- Prerender generated metadata for 7 routes, `sitemap.xml`, and `robots.txt`.
- The generated-output gate finds no `.js` artifacts or imports. The 2026-08-27
  generated Oxlint audit found three unused declarations; they are recorded as
  backend follow-ups rather than edited in `output/`.
- The live dev watcher rebuilt after a `.purs` change without restarting Vite,
  and backend SIGINT shutdown produced no exception.

These checks prove that this site can build and test on the direct-output
branch. They do not yet claim that every PureScript library or every FFI
calling convention is supported by purs-ts. New library usage should be added
with a fixture or target-project test before being treated as production
ready.
