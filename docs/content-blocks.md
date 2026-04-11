# Markdown content blocks (SSR HTML contract)

Interactive fenced blocks are emitted during the content build as `**BodyBlock` values** (`Types.BodyBlock`) in each post’s `**bodyBlocks`** array, alongside `**bodyHtml**` (concatenation of the same HTML for SEO and fallback). String HTML for tool/diff/terminal lives in `**BodyBlockHtml.purs**` (no markdown-it in the browser bundle).

`**Pages.Article`:** when `**bodyBlocks`** is non-empty, `**BodyTerminal**` → Luna `**Components.TerminalCard**`, `**BodyToolCard**` → `**Components.ToolCard**`, `**BodyDiffCard**` → `**Components.DiffCard**`, `**BodyProseHtml**` → `**unsafeRawHtml**`. When `**bodyBlocks**` is empty (e.g. before `**MergePostContent**` loads `**/data/posts/{section}/{slug}.json**`), the prose region shows a short **loading** placeholder; once blocks arrive, the client renders the same Luna tree as SSR (no DOM scrape of the article body).

On `**#app`** in `**src/Main.js**`:

- `**data-terminal-copy**` handles copy for both string and Luna terminals.
- `**data-terminal-toggle**` is only on string-built terminals (`BodyBlockHtml`); Luna `**TerminalCard**` uses `**onClick**`.
- `**data-tool-display-toggle**` is only on string-built tool/diff shells (`BodyBlockHtml`); Luna tool/diff islands use `**onClick**` and `**ToolToggle**`.

**Hydration:** `__LUNA_INITIAL_MODEL__` uses the same `**sliceManifest route manifest**` as prerender’s `**renderStatic**` for that URL, so the active `**SectionPost`** keeps `**bodyBlocks**` and drops `**bodyHtml**` (`Nothing` / JSON `null`); other posts clear both. Full HTML remains in `**generated/posts.json**`, per-post `**/data/posts/...json**`, and any future RSS output.

## Tool / diff cards (`data-component="tool-display-card"`)

Non-terminal cards share a chrome: header (file + optional stats), `**.tool-display-body**`, and an expand footer **button** (`.tool-display-expand-btn`) with `**aria-expanded`**. Luna islands set `**data-measured-island="true"**`; `**Main.js**` runs `**measureToolCards**` after paint: it reports heights to `**ToolCardMeasured**` for Luna, and for string-only cards adjusts `**tool-display-card--no-expand**` / `**is-expanded**` in the DOM.

- **Collapsed body height cap:** `200px` in `css/style.css` on `.tool-display-body`.
- **Measurement threshold:** `TOOL_DISPLAY_COLLAPSED_MAX_PX = 200` in `src/Main.js` (must stay aligned with CSS).

Chevron rotation: `**[data-component="tool-display-card"]:not(.terminal-card) button.tool-display-expand-btn[aria-expanded="…"]`** — same idea as `**.terminal-card button[aria-expanded]**`.

## Terminal cards (same `data-component` for layout only)

Terminal blocks reuse `data-component="tool-display-card"` and class `**terminal-card**`. They do **not** use `**.tool-display-body`** or the tool expand button, so `**measureToolCards**` skips them (`:not(.terminal-card)`).

### Toggle (show / hide output)

- **String HTML (`BodyBlockHtml`):** `data-terminal-toggle`, `data-target="<body element id>"`, `aria-expanded`, `aria-controls`; output `**hidden`** toggled by delegation.
- **Luna island:** header button uses `onClick` + `aria-expanded`; output region uses Luna `hidden` (no `data-terminal-toggle`). Root has `**data-block-id="<base id>"`** (stable `term-…` prefix).

### Copy command

- **Button:** `data-terminal-copy`, `data-command="<escaped command text>"`, `title` flips Copy ↔ Copied; optional `**data-copied="1"`** while showing “Copied” (used by `css/style.css` `::after`).

### Chevron rotation

- SVG class `**terminal-chevron**`; CSS rotates when `**aria-expanded="true"**`.

## Prerender / CI

Optional env `**LUNA_INLINE_MODEL_MAX_BYTES**`: when set to a positive integer, `**PrerenderMain**` fails the build if any route’s `**__LUNA_INITIAL_MODEL__**` JSON exceeds that many UTF-16 code units (ASCII-heavy payloads track bytes closely). Unset or `**0**` disables the check. Example: cap at 50k for CI with `LUNA_INLINE_MODEL_MAX_BYTES=50000`.