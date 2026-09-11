# Skill evaluation

Run date: 2026-09-10. These are read-only planning evaluations, not application implementation or browser tests.

## Baseline

Fresh BB thread `thr_gutx8u6399`, created before the suite was installed. Four requests covered a searchable product screen, missing keyboard/context updates, JS chart plus deep-link prerendering, and a wording-only near miss. The baseline found no Miso-specific skill, used the local source, and correctly identified the principal API contracts, including Response callbacks and context opt-in. This is a strong baseline; the suite should improve discoverability and consistency rather than claim those facts were previously unknown.

## Evaluation cases

1. Searchable products plus private form draft; broken keydown and stale theme. Expected: `miso-thinking`, `miso-effects`, `miso-components`, and `miso-views`; minimal owned state, derived filtering, explicit Response body adaptation, keyboard events in both entry paths, and consuming components opting into context updates.
2. JS chart with lifecycle cleanup and directly loadable prerendered `/products/42`. Expected: `miso-javascript` and `miso-routing-ssr`; actual DOMRef, single subtree owner, instance cleanup, matching server/client state, correct hydration entry signature, and build ordering that preserves generated pages.
3. Wording-only edit. Expected: no Miso skill and no architecture/build/native workflow.

## Observed results

- State/events, `thr_vtbkhazn98`: selected the four expected Miso skills and their relevant references. Its plan preserved a keyed form's draft, derived filters, adapted `Fetch.body`, gave the error response a concrete type, registered keyboard events in both startup branches, and opted nested theme consumers into context updates. It distinguished transition checks from browser validation. The transcript also showed an unnecessary read of the unrelated Foldkit audit skill before excluding it.
- Added `.bb/AGENTS.md` after that run to give future threads a direct project entry point and require reading selected skill bodies before references. This keeps Miso-specific task routing explicit without activating the suite for wording-only work.
- Compared with baseline, the state/events plan retained the correct APIs and added a more explicit draft/commit protocol, concrete error callback typing, and startup context type changes. This qualitative comparison does not isolate model variability or establish a numerical quality gain.

- Chart/hydration, `thr_5zmxx5nh82`: selected thinking, JavaScript, components, views, effects, routing/SSR, and toolchain guidance; did not select native or the unrelated Foldkit audit. It planned a retained chart instance, prop-driven updates, cleanup, initial URL parsing, SSR/client parity, and static page generation after the existing `public/` replacement. It used `DebugHydrate` and the URI-function hydration entry correctly. Transcript inspection confirmed targeted lifecycle/runtime source reads.
- That evaluation prompted a source-verified refinement: project context and widget guidance now explain that hydration fires creation hooks and that hook dispatch timing must not be confused with effect execution timing. These additional notes were checked against `ts/miso/dom.ts` and `ts/miso/hydrate.ts`; the refinement was not separately rerun as a browser test.

- Wording-only near miss, `thr_i7jbj642su`: read project guidance, selected no specialized skills, identified the hidden heading separately from the visible paragraph, and proposed only a text-diff check. Transcript inspection confirmed no skill reads, builds, or edits.

## Mechanical checks and limits

- BB's environment registry discovers all eight skills as `bb-project` entries.
- `check_docs.py --online`: eight skills and 41 routes; no structural errors, missing local links, unmapped live pages, or failed requests.
- Checker smoke checks cover duplicate manifest URLs, fragment normalization, and exclusion of external hosts/query variants.
- Native guidance was reviewed against all eight official native pages and the resolved entry, mount, effect, platform-module, and main-thread helper source. No Lynx runtime evaluation was performed.
- No application code changed. No app compilation, browser rendering, deployment, or native bundle test was needed or performed for this documentation task. The implementation examples produced by evaluators remain uncompiled outlines.
