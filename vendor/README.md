# Vendored build tools

`purs-backend-ts-0.1.0.tgz` supplies the zero-config PureScript-to-TypeScript
compiler frontend. `purescript-foldkit-0.1.0.tgz` supplies the reusable
PureScript Foldkit API and its direct TypeScript provider. Together they let
this repository build without a sibling checkout, npm publication, copied
generic FFI modules, or compiler configuration in `spago.yaml`.

Verify and install it from the repository root:

```bash
(cd vendor && sha256sum --check purs-backend-ts-0.1.0.tgz.sha256)
(cd vendor && sha256sum --check purescript-foldkit-0.1.0.tgz.sha256)
pnpm install
pnpm check:backend
```

To replace an archive, build it in the backend repository, copy the new `.tgz`
and `.sha256` here, update `package.json` if its filename/version changed, then
run `pnpm install --force` and the full `pnpm check`/`pnpm build` gates.
