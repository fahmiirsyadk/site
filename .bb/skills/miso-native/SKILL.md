---
name: miso-native
description: Build or review Haskell Miso native mobile applications using Lynx, static mounting, dual threads, main-thread handlers, MainThreadRef, or native platform APIs. Use only for explicit Miso native/mobile work; skip ordinary browser and WASM features.
---


# Miso native and Lynx

Read [thread contracts](references/native-contracts.md), then select the exact native page from [the route map](../miso-thinking/references/docs-map.md). Inspect the application's native executable, runtime, toolchain, and flags before proposing a runnable build; do not assume a native or web scaffold already exists.

1. Retain the MVU state design while replacing browser elements and startup with the native vocabulary and entry point. Check all required JSON instances and extensions in the pinned API.
2. Assign each operation to BTS or MTS explicitly. Background code owns shared state and subsequent diffs; main-thread code applies patches and performs selected imperative interactions.
3. Use static mounting for components that require cross-thread reconstruction, including children mounted after the first frame. Supply runtime values separately from static pointers.
4. Keep ordinary event handling on the background thread. Use static main-thread handlers only for an interaction whose latency warrants imperative work.
5. Guard subscriptions with `bts` or `mts` when they must run once. Dispatch cross-thread actions with `runOnBG`/`runOnMain`; do not try to transfer IO closures.
6. Verify dynamic mounting, handler dispatch, thread-specific APIs, subscription count, and per-property ownership in a Lynx runtime. A web build cannot validate native behavior.
