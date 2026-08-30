# Generated TypeScript Oxlint follow-ups

The site now applies the vendored anti-slop rules to authored TypeScript with
`pnpm lint`. Generated TypeScript remains disposable: do not edit `output/` to
silence these diagnostics. Fix generator behavior in `purs-backend-ts`, the
binding generator, or the relevant binding package.

## 2026-08-27 audit

The backend build and generated-output contract passed for 487 generated files
and 38 TypeScript FFI providers. An exploratory Oxlint scan of the generated
`.ts` and `.d.ts` files reported 632 diagnostics:

| Diagnostic                                  | Count | Backend signal                                                                                                      |
| ------------------------------------------- | ----: | ------------------------------------------------------------------------------------------------------------------- |
| `require-safety-comment-for-type-assertion` |   353 | Generated assertions need safety evidence, or a typed helper that removes the assertion.                            |
| `no-chained-type-assertions`                |    45 | Foreign exports and generated values commonly use `(value as unknown) as Type`.                                     |
| `no-unknown-type-aliases`                   |    39 | Abstract PureScript values such as `Unit`, `Element`, `Stream`, `Payload`, and `Rejected` become `unknown` aliases. |
| `no-unsafe-dictionary-type`                 |    12 | Open rows are emitted as `Record<string, unknown>` at runtime and FFI boundaries.                                   |
| `no-unknown-parameters`                     |     3 | Generated Effect/runtime callbacks expose unparsed `unknown` inputs.                                                |
| `no-runtime-typeof`                         |     2 | Compatibility FFI providers contain runtime `typeof` checks.                                                        |
| `no-known-value-widening`                   |     1 | A generated record annotation widens a value before use.                                                            |
| `no-unused-vars`                            |     3 | `row` in `Foldkit.Html.Prop`, `Link` in `Page.Post`, and `childModel` in `App.Update` are emitted but unused.       |

The remaining non-error diagnostics are generated-code style/compatibility
warnings: 140 `prefer-as-const`, 24 `no-empty-file`, 6 `no-new-array`, and 4
`no-useless-spread` findings.

## Priorities

1. Remove unused generated type parameters and aliases, especially `row`,
   `Link`, and `childModel`.
2. Replace chained foreign-boundary casts with generated typed adapters. Where
   a cast is unavoidable, emit a nearby generated `SAFETY:` explanation.
3. Preserve opaque/abstract foreign types as named boundary contracts instead
   of aliases that collapse directly to `unknown`.
4. Propagate concrete row shapes or schema-backed records where the generator
   currently emits `Record<string, unknown>`.
5. Emit `as const` for literal constructor tags and avoid unnecessary object
   spreads when the generated expression is already immutable.
6. Decide whether empty compatibility modules and legacy FFI idioms should be
   omitted, isolated in a generated compatibility profile, or modernized in
   their binding package.

The standard site lint command intentionally scans `src` and `scripts`; the
generated scan is an audit until these backend issues are resolved. The output
contract and strict TypeScript validator remain the authoritative generated
tree gates.
