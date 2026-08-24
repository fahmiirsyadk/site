---
title: Reverse-engineering Grok Build from one stripped binary
date: "2026-07-10T12:37:48+07:00"
slug: reverse-engineering-grok-build-cli
section: thought
status: published
banner: "/assets/banners/survival.jpg"
tags: ["llm", "development", "reverse-engineering", "agents"]
ogTitle: "Reverse-engineering Grok Build: Inside a Rust Agent CLI"
ogDescription: "A practical investigation of Grok Build's stripped Rust binary, ACP interface, agent loop, tool runtime, subagents, persistence model, and the safest ways to instrument it."
---

I started this investigation with a simple assumption: if the Grok terminal client was distributed as JavaScript, then understanding it might be mostly a matter of unpacking a bundle, finding source maps, and following module imports. That would have been the easy route. The installation looked small from the outside: two commands, `grok` and `agent`, both placed in `~/.grok/bin/`. But the first few terminal commands changed the direction of the investigation completely.

Grok Build 0.2.93 is not a packaged Node.js application. It is a 153 MiB stripped, statically linked Rust executable containing the TUI, ACP server, session engine, tool runtime, networking, Git integration, sandboxing, and subagent coordination in one binary. There is no JavaScript module graph to unfold. There is, however, a surprising amount of architecture still visible if we stop treating decompilation as the only way to learn from a binary.

This article follows that path: identify the artifact, recover its Rust structure from ELF metadata and embedded tracing paths, interrogate its public ACP boundary, reconstruct the agent loop, and decide where modification is actually useful. The work here was performed on my own local installation, without changing the installed executable or sending an inference request.

## Table of Contents

[1. Start with the artifact, not the interface](#start-with-the-artifact-not-the-interface)  
[2. Proving that it is native Rust](#proving-that-it-is-native-rust)  
[3. What stripped really removes](#what-stripped-really-removes)  
[4. Recovering the internal crate map](#recovering-the-internal-crate-map)  
[5. Reconstructing the agent loop](#reconstructing-the-agent-loop)  
[6. ACP is the cleanest observation point](#acp-is-the-cleanest-observation-point)  
[7. How subagents are represented](#how-subagents-are-represented)  
[8. Persistence makes the runtime inspectable](#persistence-makes-the-runtime-inspectable)  
[9. Modification without patching machine code](#modification-without-patching-machine-code)  
[10. When native decompilation is still useful](#when-native-decompilation-is-still-useful)  
[11. A practical research workflow](#a-practical-research-workflow)  
[12. What this tells us about coding agents](#what-this-tells-us-about-coding-agents)

## Start with the artifact, not the interface

The installer creates four visible paths, but only one real executable:

```text
~/.local/bin/grok  -> ~/.grok/bin/grok
~/.local/bin/agent -> ~/.grok/bin/agent

~/.grok/bin/grok  -> ../downloads/grok-linux-x86_64
~/.grok/bin/agent -> ../downloads/grok-linux-x86_64
```

That is worth checking before doing anything more sophisticated. Alternate command names sometimes activate different behavior through `argv[0]`, as BusyBox does. In this build, invoking the target through `agent` produces the same top-level CLI as `grok`. The actual non-TUI agent interface is a subcommand:

```bash
grok agent stdio
grok agent serve
grok agent headless
```

The first useful inspection is deliberately boring:

```bash
target="$HOME/.grok/downloads/grok-linux-x86_64"

file -L "$target"
sha256sum "$target"
readelf -hW "$target"
readelf -SW "$target"
readelf -dW "$target"
```

![cult](/assets/images/makima.webp)

The filesystem relationship can be reduced to one small map:

```text
invocation              installed symlink                executable

grok  ─────────►  ~/.grok/bin/grok  ───────────┐
                                               ├──► grok-linux-x86_64
agent ─────────►  ~/.grok/bin/agent ───────────┘    159,465,672 bytes

Both names resolve to the same inode and the same program.
Agent-server mode is selected later by the `grok agent …` subcommand.
```

For version 0.2.93, the result was:

| Property | Observed value |
|---|---|
| Format | ELF 64-bit, x86-64 |
| ELF type | `DYN`, used here as a position-independent executable |
| Linking | Static PIE |
| Symbols | Stripped |
| Size | 159,465,672 bytes |
| Build ID | `b2a926bda144f1fa29d85f30e4814e47c467c4ad` |
| CLI build | `f00f96316d` |
| SHA-256 | `4e0738d3b5550f3c842bc0ae69f468815c6329c008a110d0c27a694dc3401135` |

Static PIE explains several later constraints. Address-space layout randomization still applies, but there are effectively no normal shared-library boundaries to hook. `ldd` reports the executable as statically linked. Techniques built around replacing dynamically linked functions with `LD_PRELOAD` are therefore poor fits.

## Proving that it is native Rust

Searching for words like `node_modules`, `bun`, or `Node.js` is not enough. A large native application may contain those terms because it understands JavaScript projects, invokes package managers, or ships a web-development tool. The compiler metadata gives a much stronger answer:

```bash
readelf -p .comment "$target"
objdump -s -j .debug_gdb_scripts "$target"
```

The `.comment` section identifies:

```text
rustc version 1.92.0 (ded5c06cf 2025-12-08)
GCC: (GNU) 9.4.0
GCC: (Ubuntu 11.4.0-1ubuntu1~22.04.2) 11.4.0
```

The `.debug_gdb_scripts` section asks GDB to load Rust pretty-printers. Dependency paths embedded in the read-only data also name Rust crates with exact versions, including `tokio`, `reqwest`, `rustls`, `ratatui`, `rusqlite`, `git2`, `gix`, `tonic`, `prost`, `rmcp`, and `agent-client-protocol`.

This is not a thin Rust launcher around a hidden JavaScript payload. The native code section alone is more than 100 MiB. The crate inventory matches the features visible in the product: async orchestration, HTTP streaming, a terminal UI, SQLite search, Git worktrees, protobuf messages, MCP, and ACP.

The binary also contains a `.gnu_debuglink` entry:

```text
xai-grok-pager.debug
```

That filename is important. It means the release process produced or expected a separate debug-symbol artifact. The symbol file was not installed and I did not find it in the public distribution, but the exact matching file would be far more valuable than guessing function boundaries in an optimized release. GDB, Ghidra, IDA, or Binary Ninja could use it to recover names, types, and source-line associations.

## What stripped really removes

"Stripped" often gets treated as if it means "opaque." It does not. Stripping primarily removes the convenient symbol and debug tables. It does not automatically remove every string literal, serialization field, tracing event, panic location, protocol name, error message, or source path that the program needs at runtime.

Rust applications are especially generous when they use structured tracing. A call such as `tracing::event!` can preserve module and source-file metadata through `file!()` and `module_path!()`. Serde-generated code leaks structure names and field names. Clap retains command names, argument descriptions, and possible values. Protobuf and JSON-RPC layers retain method and message identifiers.

A broad `strings` dump is noisy, so I narrowed it to source-shaped patterns:

```bash
strings -a "$target" \
  | rg -o 'crates/codegen/[A-Za-z0-9_./-]+\.rs' \
  | sort -u
```

The result is not source code, but it is close to an architectural index. This is the key distinction: decompilation tries to reconstruct implementation. Metadata recovery reconstructs responsibility and boundaries. For learning how an agent works, the second one often gets us to the useful questions faster.

## Recovering the internal crate map

The first-party crate names form a fairly clean system map:

| Crate | Likely responsibility, supported by module paths |
|---|---|
| `xai-grok-pager` | Full-screen terminal UI and subagent views |
| `xai-grok-shell` | CLI, ACP sessions, orchestration, persistence, permissions |
| `xai-chat-state` | Conversation state and construction of model requests |
| `xai-grok-sampler` | Streaming inference and retries |
| `xai-grok-tools` | Built-in tool definitions and schemas |
| `xai-tool-runtime` | Tool execution protocol and progress events |
| `xai-grok-mcp` | MCP discovery and dispatch |
| `xai-grok-hooks` | Lifecycle hooks around prompts and tools |
| `xai-grok-sandbox` | Landlock/Seatbelt execution isolation |
| `xai-grok-subagent-resolution` | Child role, persona, model, and capability resolution |
| `xai-grok-compaction` | Context-window compression |
| `xai-grok-memory` | Cross-session memory |
| `xai-hunk-tracker` | File changes, diffs, rewind, and review state |

The main shell crate exposes even more specific modules:

```text
session/acp_session_impl/prompt_build.rs
session/acp_session_impl/run_loop.rs
session/acp_session_impl/sampler_turn.rs
session/acp_session_impl/tool_calls.rs
session/acp_session_impl/tool_dispatch.rs
session/acp_session_impl/turn_end.rs
session/acp_session_impl/reminders.rs
session/acp_session_impl/laziness_classifier.rs
session/persistence.rs
session/storage/jsonl.rs
agent/mvp_agent/subagent_coordinator.rs
agent/subagent.rs
```

Even without function bodies, those names expose a sequence. A session is set up, its prompt is built, a sampler turn streams model output, tool calls are collected and dispatched, results are folded back into chat state, and the turn is finalized and persisted.

There are also separate goal-related modules: planner, strategist, summarizer, classifier, tracker, verifier, and stop detector. One embedded prompt belongs to a strict JSON classifier that decides whether the main agent is stalled. It looks for narration that claims an action without a matching tool call, or a completion claim unsupported by tool evidence. This is a useful reminder that what feels like one agent in the UI can actually include several narrow model-assisted control passes around the primary conversation.

## Reconstructing the agent loop

Putting together the crate names, protocol fields, local documentation, and session format produces this high-level loop:

```text
                         build model request
                                  │
                                  ▼
┌──────────── request_builder: model-visible context ────────────┐
│ system prompt                                                  │
│   ├── selected agent definition                                │
│   ├── AGENTS.md + applicable project rules                     │
│   ├── skills, memory, plan state, and reminders                │
│   └── available local + MCP tool schemas                       │
│                                                                │
│ conversation                                                   │
│   └── prior messages + tool results + current user prompt      │
└──────────────────────────────┬─────────────────────────────────┘
                               │ serialized request
                               ▼
                       inference backend
```

The request enters the session run loop. The backend produces a stream rather than one monolithic answer. Text can be rendered immediately, while a tool call creates a local execution detour and then feeds its result into another model pass:

```text
                             session/prompt
                                   │
                                   ▼
┌──────────── session run_loop ────────────────────────────────┐
│ prompt_build → sampler_turn → streaming backend              │
│                                                              │
│ text / reasoning                                             │
│   └──► emit ACP/TUI update + append updates.jsonl            │
│                                                              │
│ tool_call                                                    │
│   └──► tool_dispatch → structured result → chat state        │
│                                                │             │
│                         next sampler turn ◄────┘             │
│                                                              │
│ final status                                                 │
│   └──► turn_end → signals + persistence                      │
│          └──► reminders / compaction check                   │
└──────────────────────────────────────────────────────────────┘
```

That detour is a pipeline of gates. A denial stops before execution; approval continues toward the operating-system boundary:

```text
                             tool_call(args)
                                   │
                                   ▼
┌──────────── local tool dispatcher ────────────────────────────┐
│ 1. deserialize and validate arguments                         │
│        │                                                      │
│ 2. run matching PreToolUse hooks ───── deny ────┐             │
│        │ allow / no decision                    │             │
│ 3. evaluate permission rules ───────── deny ────┤             │
│        │ allow / user approves                  │             │
│ 4. enter OS sandbox                             │             │
│        │                                        │             │
│        └──► file / shell / Git / MCP / web / subagent         │
│                    │                            │             │
│                    └── success or error ────────┤             │
│                                                 ▼             │
│                          normalize as structured tool result  │
└──────────────────────────────┬────────────────────────────────┘
                               │ structured result
                               ▼
                    chat state → next model pass
```

"Build request context" is doing a lot of work here. It can include the base system prompt, selected agent definition, project instruction files such as `AGENTS.md`, skill descriptions, memory, MCP tools, file references, prior conversation, plan state, reminders, and the current tool schemas. The `xai-chat-state` request builder then serializes that state for the selected backend.

The model is not directly executing shell commands. It emits a structured request. The client decides whether the tool exists, whether its arguments deserialize, whether a hook denies it, whether permission policy allows it, and whether the operating-system sandbox permits the underlying action. This separation matters because "the model can use Bash" really means "the harness exposed a Bash-shaped schema and agreed to execute a validated request under several local policy layers."

The ordering documented by Grok Build is:

1. Blocking `PreToolUse` hooks.
2. Explicit permission rules, with deny taking precedence.
3. Built-in fast paths for read-only or recognized-safe operations.
4. The active prompt policy, such as asking the user or always approving.
5. The OS sandbox, which remains a separate enforcement boundary.

The official enterprise documentation confirms that the Linux sandbox uses Landlock and that network communication uses `rustls`, not OpenSSL.[^enterprise] The dependency inventory in the binary independently matches both claims.

## ACP is the cleanest observation point

Native disassembly is not the only interface. Grok Build implements the Agent Client Protocol, a JSON-RPC protocol designed for editors and other agent clients.[^acp] Its standard input mode can be queried without opening the interactive TUI:

```bash
grok agent --no-leader stdio
```

I sent a single `initialize` request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": 1,
    "clientCapabilities": {
      "fs": {
        "readTextFile": true,
        "writeTextFile": true
      },
      "terminal": true
    },
    "clientInfo": {
      "name": "local-analysis",
      "version": "0"
    }
  }
}
```

The response advertised session loading, embedded context, MCP over HTTP and SSE, filesystem notifications, blocking pre-tool hooks, model state, and built-in commands including `compact`, `context`, `session-info`, and `goal`. No inference request was needed to learn this.

ACP gives us a stable seam between presentation and orchestration:

```text
ACP client ⇄ JSON-RPC over stdin/stdout ⇄ grok agent stdio
                                              │
                                              ▼
┌──────────── ACP request router + session manager ─────────────┐
│ initialize                                                    │
│   └──► return protocol, agent, auth, and MCP capabilities     │
│                                                               │
│ session/new or session/load                                   │
│   └──► create or restore an active AcpSession                 │
│                                                               │
│ session/prompt                                                │
│   └──► active session run_loop                                │
│             ├──► inference backend                            │
│             ├──► built-in tools + configured MCP servers      │
│             └──► session state                                │
│                      │                                        │
│                      ├──► persist updates.jsonl               │
│                      └──► emit session/update to client       │
│                                                               │
│ tool approval                                                 │
│   └──► session/request_permission ⇄ client response           │
└───────────────────────────────────────────────────────────────┘
```

The client sends `initialize`, `session/new`, `session/load`, and `session/prompt` requests. Grok returns normal JSON-RPC responses and streams `session/update` notifications containing message chunks, thought chunks, plans, and tool state. When a tool requires approval, Grok sends the client a `session/request_permission` request and waits for its response. The client sees these protocol state transitions, not Rust function calls.

A transparent ACP proxy is therefore one of the best research tools for this application. It can log method names, session updates, reasoning chunks exposed by the protocol, permission requests, tool-call status, plans, and final messages. It will not reveal every internal Rust call, but it reveals the state transitions that actually matter to an editor or orchestration client.

The product itself officially supports interactive, headless, and ACP modes.[^overview] That makes ACP observation less brittle than hooking private functions whose addresses may change in every release.

## How subagents are represented

Subagents are not threads sharing one prompt buffer. They are child sessions with their own conversation context. The parent model requests one through a `spawn_subagent` tool, passing a task description and an agent type. Resolution then combines the selected role with optional model overrides, persona instructions, capability restrictions, and isolation settings.

The built-in roles are:

| Type | Default purpose |
|---|---|
| `general-purpose` | Full-capability implementation and general work |
| `explore` | Read/search/execute investigation without file editing |
| `plan` | Codebase exploration followed by an implementation plan |

Capabilities can be restricted independently to read-only, read-write, execute, or all. Isolation is either the shared working directory or a separate Git worktree. A background child returns immediately with an ID; the parent later retrieves its progress or result. A blocking child holds the parent call until completion.

```text
┌───────────────────────────────────────────────────────────────────────┐
│ PARENT SESSION                                                        │
│                                                                       │
│ model decides that a bounded task can be delegated                    │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    │ spawn_subagent {
                                    │   prompt, description, type,
                                    │   background, capability, isolation
                                    │ }
                                    ▼
                      ┌───────────────────────────┐
                      │ subagent resolution       │
                      │                           │
                      │  1. choose agent role     │
                      │  2. apply persona         │
                      │  3. resolve model         │
                      │  4. restrict tools        │
                      │  5. choose cwd/worktree   │
                      └─────────────┬─────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│ CHILD SESSION                                                         │
│                                                                       │
│ separate context window     separate transcript     normal agent loop │
│                                                                       │
│              workspace choice:                                        │
│              ┌────────────────────┐     ┌─────────────────────────┐   │
│              │ same working tree  │ OR  │ isolated Git worktree   │   │
│              └────────────────────┘     └─────────────────────────┘   │
└───────────────────────────────────┬───────────────────────────────────┘
                                    │
                      progress ─────┼───── completion
                                    │
                                    ▼
                      ┌───────────────────────────┐
                      │ compact result / summary  │
                      └─────────────┬─────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│ PARENT CONTINUES                                                      │
│ full child transcript stays separate; only the result enters context  │
└───────────────────────────────────────────────────────────────────────┘

Depth limit: parent → child. A child cannot create a grandchild.
```

Only the child pays for its full working transcript in its context window. A background child returns an ID immediately and the parent retrieves its progress or completion later with `get_command_or_subagent_output`.

The nesting depth is intentionally one: only the top-level session can spawn subagents. This keeps the graph flat and prevents recursive fan-out. A resumed child can inherit a completed child transcript, tool state, model, and working directory, but its current system prompt and tools are rendered again from the active agent definition. The source child must be complete, belong to the current parent session, and use the same agent type.

This architecture explains why subagents save context in the parent. The parent does not need every search result and failed command in its own history. It receives a compressed result while the complete child transcript remains separately inspectable.

## Persistence makes the runtime inspectable

Every mode writes the same general session model under `~/.grok/sessions/`. A session directory contains files such as:

```text
                         append(session event)
                                  │
                                  ▼
┌──────────── session directory (source of truth) ──────────────┐
│ ├── updates.jsonl → ACP event stream → restore / TUI replay   │
│ ├── chat_history.jsonl → raw messages for model requests      │
│ ├── summary.json → title, model, timestamps, message counts   │
│ ├── signals.json → token, turn, and tool counters             │
│ ├── plan.json → task state                                    │
│ ├── rewind_points.jsonl → file restoration                    │
│ └── subagents/ → child metadata                               │
│                                                               │
│ compaction_checkpoints/ → transformed conversation snapshots  │
└───────────────────────────────────────────────────────────────┘

search: titles + prompts → SQLite FTS index
```

`updates.jsonl` is the ACP-style event stream used for restoration. `chat_history.jsonl` contains the raw conversation messages used by the model-facing state. Smaller JSON files track plans, usage signals, summaries, and rewind state. Session search additionally maintains a SQLite FTS index.

This is more useful than it first appears. To understand an agent turn, we can correlate:

- the user message in `chat_history.jsonl`;
- emitted reasoning and tool events in `updates.jsonl`;
- the tool result attached to the next model request;
- turn and token counters in `signals.json`;
- child metadata under `subagents/`;
- debug logs enabled with `--debug-file`.

That creates a behavioral trace without touching the ELF. It also separates two commonly confused histories: what the user interface rendered and what the model actually received after normalization, pruning, repair, or compaction.

Embedded log messages show that the chat-state layer repairs duplicate results and dangling tool calls after crashes. Compaction has its own checkpoints and transcript transformation code. This means a resumed session is not simply replaying a text file; it is reconstructing a consistent state machine from persisted events.

## Modification without patching machine code

If the goal is to learn how the agent behaves, patching instructions in `.text` should be near the bottom of the list. Grok Build already exposes several modification layers with much better stability.

```text
least invasive / most update-resistant
                    │
                    ▼
1. config + rules       change prompts, agents, tools, and models
                    │
2. lifecycle hooks      observe or deny tool execution
                    │
3. ACP proxy            observe requests, updates, and permissions
                    │
4. local model endpoint  capture the exact model-facing request
                    │
5. native decompiler    recover private control flow
                    │
6. binary patch         modify strings or machine instructions
                    │
                    ▼
most invasive / tied to one release build
```

### Replace or extend the prompt

The CLI supports both:

```bash
grok --rules "Additional session-specific rules"
grok --system-prompt-override "A complete replacement system prompt"
```

Project `AGENTS.md` files, custom agent definitions under `.grok/agents/`, personas, and role prompt files offer more durable variants. These are ideal for testing whether a behavior comes from prompting or from harness logic.

### Interpose at the lifecycle boundary

Hooks can observe session start, user prompts, tool requests, results, permission denial, compaction, subagent start/stop, and turn completion. `PreToolUse` hooks can deny an operation. Passive hooks can log a structured event stream.

This is the right layer for experiments such as:

- recording every tool and its arguments;
- blocking a command family;
- measuring time between model output and tool completion;
- comparing main-agent and subagent tool patterns;
- injecting controlled environment state at session start.

### Wrap ACP

A small proxy can launch `grok agent stdio`, forward newline-delimited JSON in both directions, and write a timestamped copy. Because it works at the documented protocol boundary, it should survive internal Rust refactors better than an address-based hook.

### Capture the model-facing request locally

Grok supports custom OpenAI-compatible model endpoints. In an isolated lab configuration, a local endpoint can capture the request body and return a canned response. The important safety rules are to use a temporary `GROK_HOME`, a dummy API key, and an empty test workspace so no real credentials, project instructions, memory, or private source code enter the capture.

A minimal model definition looks conceptually like this:

```toml
[models]
default = "capture"

[model.capture]
model = "capture"
base_url = "http://127.0.0.1:8080/v1"
api_key = "dummy"
context_window = 128000
```

This experiment can reveal the exact rendered system prompt, message ordering, tool schemas, reminders, and provider API dialect. For studying an agent harness, that is usually more informative than pseudocode reconstructed from optimized assembly.

## When native decompilation is still useful

There are questions the public boundaries cannot answer. Native analysis becomes useful when we need the precise precedence of undocumented flags, the implementation of a parser, a hidden state transition, the source of a crash, or the location of an internal constant.

The practical route would be:

1. Preserve the original hash and work on a copy.
2. Import the ELF as x86-64 little-endian in Ghidra, IDA, or Binary Ninja.
3. Mark the image as PIE and use the ELF program headers rather than guessing a base address.
4. Apply Rust demangling and known library signatures.
5. Use embedded source paths and tracing strings to label functions by responsibility.
6. Locate cross-references to distinctive errors or protocol method strings.
7. Compare behavior across two releases to separate stable subsystems from compiler noise.
8. Load `xai-grok-pager.debug` if an exact matching symbol artifact becomes available.

The best initial targets are not `main`. Optimized Rust startup mostly leads into runtime and argument-parsing machinery. Better anchors are distinctive strings associated with:

```text
session/prompt
session/request_permission
spawn_subagent
tool.call
tool.cancel
compact_conversation
active_sessions.json
updates.jsonl
```

From each string, follow read-only-data references into code, then expand the call graph. Serde and protobuf-generated functions can be large and repetitive, so they should be labeled early to avoid mistaking serialization machinery for business logic.

Binary patching is possible, but the useful cases are narrow. A same-length string replacement in `.rodata` is manageable. Changing string length requires relocating data or rewriting references. Control-flow patches must account for optimized code, RIP-relative addressing, unwinding metadata, and ASLR. The internal updater will replace the modified artifact on the next update.

Because the binary is statically linked, `LD_PRELOAD` will not give normal interposition points. Because HTTPS is implemented with `rustls`, OpenSSL function hooks will not expose plaintext. Explicit protocol proxies, custom endpoints, ACP wrappers, hooks, `ptrace`, or uprobes are more appropriate depending on the question.

## A practical research workflow

If I continued this project, I would avoid starting with a full decompile. I would build the evidence in layers:

### Phase one: inventory

```bash
file -L "$target"
readelf -hW "$target"
readelf -SW "$target"
readelf -p .comment "$target"
readelf -x .gnu_debuglink "$target"
strings -a "$target" | rg 'crates/codegen|session/prompt|spawn_subagent'
```

Record the version, build ID, compiler, hash, sections, source paths, dependencies, endpoints, environment variables, and protocol identifiers.

### Phase two: observe public behavior

Run the ACP initialization handshake, enumerate CLI help recursively, inspect discovered configuration with `grok inspect`, and read the locally installed user guide. None of these steps requires a paid model turn.

### Phase three: trace one controlled session

Use an empty repository and a harmless prompt. Save ACP traffic, debug logs, session JSONL, hooks, and filesystem changes. Correlate events by session ID and tool-call ID.

### Phase four: isolate one question

Examples:

- What exactly is sent to a subagent?
- When is a stalled turn automatically continued?
- How does permission precedence handle conflicting rules?
- Which content survives compaction?
- Does a resumed child inherit the old prompt or re-render the current one?

Use the least invasive boundary that answers the question. Only move to native decompilation if ACP, hooks, logs, persistence, and a controlled endpoint cannot resolve it.

### Phase five: patch a disposable copy

If a machine-code modification is genuinely necessary, redirect a separate launcher to the copy and disable auto-update for the experiment. Never edit the symlink target without a rollback path. Verify the copy's hash before and after every change and document file offsets separately from runtime virtual addresses.

## What this tells us about coding agents

The most interesting result is not that Grok Build is written in Rust. It is how much of the "agent" lives outside the model.

The model proposes text and structured actions, but the harness constructs its context, defines the available actions, validates arguments, asks for permission, executes tools, stores results, repairs history, compacts old context, coordinates child sessions, detects stalls, manages worktrees, and decides when a turn has actually ended. The visible personality may come from a prompt and a model, but reliability comes from a state machine surrounding them.

That state machine is also the most practical place to learn. ACP shows the session boundary. Hooks show policy decisions. JSONL shows history. A local model endpoint shows the rendered request. The ELF fills in the internal subsystem names and helps answer the remaining implementation questions.

So the original JavaScript hypothesis was wrong, but the conclusion is better: we do not need source maps to understand an agent harness. We need to identify its boundaries, choose the right observation point, and separate evidence from inference. Native code makes the last ten percent harder. It does not hide the shape of the system.

At the time of this investigation, xAI describes Grok Build as an early-beta coding agent supporting TUI, headless automation, ACP, skills, plugins, hooks, MCP, and subagents.[^launch] The public xAI GitHub organization did not list the CLI source itself, so the local artifact and its documented protocols remain the primary material for this kind of study.[^xai-github]

[^overview]: xAI, ["Grok Build"](https://docs.x.ai/build/overview), official product and CLI overview.

[^enterprise]: xAI, ["Enterprise Deployments"](https://docs.x.ai/build/enterprise), including network, configuration, authentication, sandbox, permission, and TLS details.

[^acp]: [Agent Client Protocol](https://agentclientprotocol.com), the JSON-RPC protocol used by `grok agent stdio`.

[^launch]: xAI, ["Introducing Grok Build"](https://x.ai/news/grok-build-cli), May 25, 2026.

[^xai-github]: [xAI's public GitHub repositories](https://github.com/orgs/xai-org/repositories), checked during the investigation on July 10, 2026.
