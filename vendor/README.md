# Vendored build tools

`purs-backend-ts-0.1.0.tgz` is a locally built npm package for the PureScript
TypeScript backend. It lets this repository build without a sibling backend
checkout or npm publication.

Verify and install it from the repository root:

```bash
(cd vendor && sha256sum --check purs-backend-ts-0.1.0.tgz.sha256)
pnpm install
pnpm check:backend
```

To replace it with a new backend version, run
`npm run release:purs-ts-tarball` in the backend repository, copy the new `.tgz`
and `.sha256` here, update `package.json`, then run `pnpm install` and the full
`pnpm check`/`pnpm build` gates.
