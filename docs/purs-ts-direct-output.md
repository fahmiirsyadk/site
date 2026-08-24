# Direct purs-ts output

This branch uses the TypeScript backend as the application boundary:

```text
PureScript source
      │ purs / Spago
      ▼
CoreFn in output/
      │ purs-ts backend
      ▼
output/**/*.ts
      │ Vite / Node
      ▼
browser application
```

The generated TypeScript is the application-facing API. Public functions are
exported with the backend's uncurried calling convention, generated relative
imports use `.ts`, and the Effect runtime is emitted as `effect-runtime.ts`.
The browser entrypoint imports the generated `App.Entry` module and executes
its Effect with the generated runtime.

## What was removed

The old declaration bridge is no longer part of the build:

- `ts-bridge` was removed from `spago.yaml`.
- `src/Bridge/Generate.purs` and `src/Bridge/Wire.purs` were removed.
- `generate:types` is no longer a build step.
- TypeScript consumers import generated modules from `output/` directly.

The backend wrapper is [`scripts/purs-ts-backend.mjs`](../scripts/purs-ts-backend.mjs).
By default it resolves the installed, self-contained package at
`node_modules/purs-backend-ts/dist/purs-ts.mjs`. The package comes from the
versioned tarball under `vendor/`, so builds do not require a sibling backend
checkout or npm publication. A backend developer can set `PURS_TS_BACKEND` to
an alternate CLI path explicitly.

## TypeScript FFI boundary

Removing the Bridge does not remove platform FFI. FFI is still the appropriate
boundary for operations supplied by TypeScript or the browser platform,
including DOM, WebGL, Foldkit constructors and commands, and content/build
adapters. Site-owned providers are `.ts` siblings of their `.purs` modules.
The backend prefers those providers and emits them as `foreign.ts`.

Dependencies that only ship traditional PureScript `.js` providers remain
compatible: the backend converts each reachable provider into a generated
`foreign.ts` compatibility module with `@ts-nocheck`. Generated `index.ts`
modules expose the PureScript-derived types and do not import or re-export
`foreign.js`. Consequently, the application output and its runtime module graph
contain no JavaScript FFI files even while upstream packages migrate gradually.

The policy is therefore:

```text
PureScript application logic  → generated .ts
PureScript Effect operations  → generated Effect v4 code
Browser/platform primitives   → small TypeScript FFI providers
TypeScript application glue   → direct imports of generated .ts
```

FFI providers must not recreate the old Bridge API. They may expose only the
native operation required by the PureScript declaration. `App.Wire.Message`
now constructs the complete raw command-result envelope in PureScript; Foldkit
passes that generated type end-to-end rather than recreating or normalizing
message records in TypeScript. `Runtime.Scribble` likewise owns selection and
the animation plan. The remaining browser TypeScript executes DOM, WebGL,
Foldkit, Vite content-loading, randomness, and observer APIs.

Use this ownership test before adding browser TypeScript:

| Concern | Owner |
| --- | --- |
| state, decisions, data transforms, wire messages, animation plans | `.purs` |
| DOM/WebGL calls, events/observers, Foldkit commands, Vite loaders | `.ts` FFI/platform adapter |
| generated application/runtime modules | `output/**/*.ts` (never edit) |

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

`build:ps` clears generated `output/`, runs Spago, and invokes the backend for
the selected application modules. `check:generated` fails if a required host
root is missing, any `.js` artifact exists, or generated TypeScript imports
JavaScript. `pnpm build` then runs the Vite production build and metadata
prerender. `pnpm dev` performs the same initial backend build before Vite starts;
the Vite plugin rebuilds and reloads after `.purs` or Interop `.ts` changes.

Agents should use the command contract documented in `AGENTS.md`. A successful
compile prints `Compiling with backend "node"` followed by `Backend build
succeeded`; seeing only a normal PureScript JavaScript build is a configuration
failure on this branch.

## Migration rating

The application migration is **9.2/10**. The application and platform FFI are
TypeScript-only at runtime, the Bridge is gone, compile/test/build/dev use the
alternate backend, portable runtime behavior and wire-message construction are
PureScript-owned, and regression checks enforce the boundary. The site now
installs the self-contained local `0.1.0` tarball directly, with checksum,
clean-install, and full browser-runtime acceptance tests. The remaining 0.8 is
ecosystem/release hardening: cross-platform CI,
publication/provenance, broader CoreFn coverage, and elimination of unchecked
compatibility copies for upstream JavaScript FFI.

## Verified evidence

On 2026-08-24 with Node 24.19.0:

- FFI validation checked 49 PureScript files and required `.ts` siblings for
  every module with value-level foreign imports.
- PureScript compiled 230 modules with 0 warnings and 0 errors.
- The purs-ts backend completed successfully.
- Strict TypeScript checking passed with `tsc --noEmit`.
- Vitest passed 6 files and 32 tests.
- Vite transformed 457 modules and produced the production bundle.
- Prerender generated metadata for 7 routes, `sitemap.xml`, and `robots.txt`.
- Generated output contains no `.js` files or `.js` imports; 17 reachable FFI
  providers are emitted as `foreign.ts`.

These checks prove that this site can build and test on the direct-output
branch. They do not yet claim that every PureScript library or every FFI
calling convention is supported by purs-ts. New library usage should be added
with a fixture or target-project test before being treated as production
ready.
