# Native thread contracts

| Concern | Rule | Source |
| --- | --- | --- |
| Entry/build | Enable the native package flag and use GHC JS plus Lynx bundling. `native`/`nativeWithContext` boot the root. | [Overview](https://haskell-miso.org/docs/native/overview/) |
| Ownership | MTS paints the first frame; BTS controls subsequent state transitions and diff patches. MTS receives an eventually consistent model replica. | [Dual thread](https://haskell-miso.org/docs/native/dual-thread/) |
| Static identity | Enable `StaticPointers`; use `vcomp` and the appropriate static mounting helper. Static expressions cannot capture local runtime bindings. Later browser-style mounts can lack the MTS mirror needed by main handlers. | [Static mounting](https://haskell-miso.org/docs/native/static-mounting/) |
| Crossing threads | Send serializable actions with `runOnBG` or `runOnMain`. Static subscriptions mount on both threads, so gate single-owner resources. | [Effects and threads](https://haskell-miso.org/docs/native/effects-and-threads/) |
| Events | Plain handlers execute on BTS. Main variants use `event (static ...)`; do not capture live props/context. Their model argument can lag BTS state. | [Main-thread events](https://haskell-miso.org/docs/native/main-thread-events/) |
| Local gesture state | Use `MainThreadRef` on MTS with a separate `NOINLINE` pragma for each top-level allocation. Use `eachFrame` for imperative frame work and stop its loop deliberately. | [Main-thread state](https://haskell-miso.org/docs/native/main-thread-state/) |
| Platform API | Import `Miso.Native.Module` for BTS native modules and `Miso.Native.MainThread` for MTS element operations. A wrong-thread call can fail or do nothing. | [Platform APIs](https://haskell-miso.org/docs/native/platform-apis/) |
| Minimal UI | Native `view_`, `text_`, `onTap`, and `nativeEvents` replace their browser counterparts. Complete the example's extensions, imports, and serialization constraints before compiling. | [Minimal component](https://haskell-miso.org/docs/native/minimal-component/) |

Give each `(element, property)` one writer. If MTS animates a transform, BTS's declarative view must not overwrite that same transform. Keep updated props/context needed by MTS in an explicit action payload or modeled value: MTS's initial copies are not kept current. Shared model changes must return to BTS; imperative MTS actions do not request a declarative repaint.
