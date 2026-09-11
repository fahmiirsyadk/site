# Integration lifetime

Read this for DOM widgets, canvas, or long-lived JS callbacks.

## Widgets

Treat a chart or editor as a resource with a defined owner. The view supplies a container, and an `onCreatedWith` action supplies its `DOMRef`. Initialize the library after that event, retain the handle if later updates need it, and destroy the instance/listeners when its owner disappears. Confirm the destruction hook's timing before relying on an attached element.

In the inspected Miso 1.13.0.0 runtime, creation hooks also run during hydration. Verify the target release's lifecycle behavior. Keep initialization idempotent and schedule it through the action, after Miso has associated the host with its VDOM. Verify attachment before DOM measurements. A lifecycle hook dispatches an action; its name alone does not guarantee the eventual IO runs synchronously before detachment. See [compatibility notes](../../miso-thinking/references/compatibility.md).

Have one renderer own a subtree. If the library edits descendants, avoid rendering competing Miso children into that container. Update the existing widget when its data changes instead of rebuilding it on every parent render. Handle delayed library loading and callbacks arriving after teardown. Include production assets in the actual HTML/build pipeline; component script injection is a development feature.

Sources: [View lifecycle](https://haskell-miso.org/docs/view-dsl/), [Components](https://haskell-miso.org/docs/components/), [Development](https://haskell-miso.org/docs/development/).

## Canvas

`Miso.Canvas.canvas` separates one-time initialization from drawing with retained initialization state. Let the draw callback capture the current model. Use the canvas module's `canvas_` when no initialization state is required; distinguish it from the HTML element constructor of the same name.

Drawing runs in `Canvas`, which provides access to the 2D context in IO. Qualify `Miso.Canvas` and `Miso.CSS` to avoid collisions such as `color`. For movement, use `rAFSub` timestamps and model actions instead of assuming timer ticks always arrive at a fixed frame rate. Decide how resizing affects drawing coordinates and canvas dimensions, and verify mount/unmount stops the animation source.

The browser test should cover first draw, data update, resize if supported, and remount without duplicate listeners or loops.

Source: [Canvas](https://haskell-miso.org/docs/canvas/). Resize checks and explicit subtree ownership are integration practices, not extra framework APIs.
