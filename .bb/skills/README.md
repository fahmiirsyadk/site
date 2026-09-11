# Miso skills

Eight reusable skills for Haskell Miso, derived from the official documentation. They cover framework architecture and APIs across browser, server rendering, and native targets. Each project supplies its own dependency version, build commands, source layout, and styling conventions.

Start with [Thinking in Miso](miso-thinking/SKILL.md) for feature architecture. The [complete documentation map](miso-thinking/references/docs-map.md) assigns all 41 documentation routes to a skill and a local reference. [Compatibility notes](miso-thinking/references/compatibility.md) explain version checks and record observed tutorial/API mismatches.

| Skill | Task |
| --- | --- |
| [miso-thinking](miso-thinking/SKILL.md) | Model design, ownership, architecture, React translation, documentation navigation |
| [miso-views](miso-views/SKILL.md) | HTML, events, forms, keys, fragments, CSS and Tailwind |
| [miso-components](miso-components/SKILL.md) | Props, context, lifecycle, mailbox and PubSub |
| [miso-effects](miso-effects/SKILL.md) | Updates, async IO, HTTP, subscriptions, strings, JSON and lenses |
| [miso-javascript](miso-javascript/SKILL.md) | Browser FFI, JavaScript EDSL, quasiquotes, DOM widgets and canvas |
| [miso-routing-ssr](miso-routing-ssr/SKILL.md) | Routes, history, static HTML and hydration |
| [miso-toolchain](miso-toolchain/SKILL.md) | Nix/Cabal builds, WASM/JS, reload and diagnostics |
| [miso-native](miso-native/SKILL.md) | Lynx builds, static mounting and thread ownership |

Keep this suite together: companion skills share the route map and compatibility notes through relative links. Install the eight directories into a supported skill root. BB supports `.bb/skills` for a project and `~/.bb/skills` for user-wide availability; an already running thread may retain its original catalog. Installation scope does not restrict the guidance to a particular application. Keep application-specific instructions in that application's `AGENTS.md`.

From the directory containing the eight skill directories, validate names, links, and route ownership:

```sh
python3 miso-thinking/scripts/check_docs.py
```

Check live route coverage without changing files:

```sh
python3 miso-thinking/scripts/check_docs.py --online
```

The online check discovers additions/removals and failed routes. It does not certify unchanged API content; re-read relevant documentation and resolved source when updating a skill. Full upstream pages are not vendored. See [evaluation results](miso-thinking/references/evaluation.md) for what was checked.
