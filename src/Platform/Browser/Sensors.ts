// Browser-platform sensors: requestAnimationFrame loops, observers, pointer
// events, DOM reads, and mutable cells. Every export is a native browser
// operation only — all decisions about *when* to react live in the PureScript
// modules that import this sibling. Exports are curried so the generated
// foreign declarations stay fully typed; callbacks return Effect values, run
// here via `Effect.runSync` (the PursTs.Effect runtime is effect v4).
import { Effect } from 'effect'

type Cleanup = () => void

export type Bounds = Readonly<{ width: number, height: number }>

export type PointerSample = Readonly<{
  kind: 'down' | 'move' | 'up'
  x: number
  y: number
  pointerId: number
}>

export type ChildListDelta = Readonly<{ added: ReadonlyArray<Element>, removed: ReadonlyArray<Element> }>

type Cell<A> = { value: A }

export const newCell = <A>(value: A): Effect.Effect<Cell<A>> => Effect.sync(() => ({ value }))

export const readCell = <A>(cell: Cell<A>): Effect.Effect<A> => Effect.sync(() => cell.value)

export const writeCell = <A>(cell: Cell<A>): (value: A) => Effect.Effect<void> =>
  value => Effect.sync(() => {
    cell.value = value
  })

export const composeCleanups = (cleanups: ReadonlyArray<Cleanup>): Cleanup => () => {
  for (const cleanup of cleanups) cleanup()
}

export const runCleanup = (cleanup: Cleanup): Effect.Effect<void> => Effect.sync(() => cleanup())

// Turns an effect into a cleanup action, for one-shot teardown steps (clearing
// mount markers) inside composeCleanups.
export const cleanupOfEffect = (effect: Effect.Effect<void>): Cleanup => () => {
  Effect.runSync(effect)
}

// A cleanup that reads the current value of a cell at invocation time, so a
// restartable resource (an animation loop) is always torn down in its latest
// incarnation.
export const cleanupOfCell = (cell: Cell<Cleanup>): Cleanup => () => cell.value()

const runCallback = (callback: () => Effect.Effect<void>): void => {
  Effect.runSync(callback())
}

// A loop whose tick returns `false` stops scheduling; the PureScript side may
// start a fresh loop later (visibility, image load, theme changes).
export const startLoop = (tick: (timestamp: number) => Effect.Effect<boolean>): Effect.Effect<Cleanup> =>
  Effect.sync(() => {
    let handle = 0
    let stopped = false
    const frame = (timestamp: number): void => {
      if (stopped) return
      let keepGoing = true
      try {
        keepGoing = Effect.runSync(tick(timestamp))
      } catch {
        stopped = true
        return
      }
      if (keepGoing && !stopped) handle = requestAnimationFrame(frame)
    }
    handle = requestAnimationFrame(frame)
    return () => {
      stopped = true
      cancelAnimationFrame(handle)
    }
  })

export const onPointer = (
  element: Element,
): (options: Readonly<{ capture: boolean, preventDefault: boolean }>) =>
  (onSample: (sample: PointerSample) => Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  options => onSample =>
  Effect.sync(() => {
    const down = (event: Event): void => {
      // SAFETY: registered as a `pointerdown` listener, so the event is a PointerEvent.
      const pointer = event as PointerEvent
      if (options.preventDefault) pointer.preventDefault()
      if (options.capture && element instanceof HTMLElement) element.setPointerCapture(pointer.pointerId)
      runCallback(() =>
        onSample({ kind: 'down', x: pointer.clientX, y: pointer.clientY, pointerId: pointer.pointerId }),
      )
    }
    const move = (event: Event): void => {
      // SAFETY: registered as a `pointermove` listener, so the event is a PointerEvent.
      const pointer = event as PointerEvent
      runCallback(() =>
        onSample({ kind: 'move', x: pointer.clientX, y: pointer.clientY, pointerId: pointer.pointerId }),
      )
    }
    const up = (event: Event): void => {
      // SAFETY: registered as a `pointerup` listener, so the event is a PointerEvent.
      const pointer = event as PointerEvent
      runCallback(() =>
        onSample({ kind: 'up', x: pointer.clientX, y: pointer.clientY, pointerId: pointer.pointerId }),
      )
    }
    element.addEventListener('pointerdown', down)
    element.addEventListener('pointermove', move)
    element.addEventListener('pointerup', up)
    element.addEventListener('pointercancel', up)
    return () => {
      element.removeEventListener('pointerdown', down)
      element.removeEventListener('pointermove', move)
      element.removeEventListener('pointerup', up)
      element.removeEventListener('pointercancel', up)
    }
  })

export const observeResize = (
  element: Element,
): (onChange: (bounds: Bounds) => Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  onChange =>
  Effect.sync(() => {
    const emit = (): void => {
      const bounds = element.getBoundingClientRect()
      runCallback(() => onChange({ width: bounds.width, height: bounds.height }))
    }
    const observer = new ResizeObserver(emit)
    observer.observe(element)
    return () => observer.disconnect()
  })

export const observeTheme = (onChange: (dark: boolean) => Effect.Effect<void>): Effect.Effect<Cleanup> =>
  Effect.sync(() => {
    const isDark = (): boolean => document.documentElement.classList.contains('dark')
    const observer = new MutationObserver(() => runCallback(() => onChange(isDark())))
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
    return () => observer.disconnect()
  })

export const isDarkTheme: Effect.Effect<boolean> = Effect.sync(() =>
  document.documentElement.classList.contains('dark'),
)

export const observeVisibility = (
  marginPx: number,
): (element: Element) => (onChange: (visible: boolean) => Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  element => onChange =>
  Effect.sync(() => {
    const observer = new IntersectionObserver(entries => {
      const entry = entries[0]
      if (entry === undefined) return
      runCallback(() => onChange(entry.isIntersecting))
    }, { rootMargin: `${marginPx}px` })
    observer.observe(element)
    return () => observer.disconnect()
  })

// Mirrors the camelCase-to-dasherized mapping of `element.dataset`: the name
// "ditherInitialized" addresses the attribute "data-dither-initialized".
const dataAttributeName = (name: string): string =>
  `data-${name.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`

export const observeDataAttribute = (
  element: Element,
): (name: string) => (onChange: (value: string) => Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  name => onChange =>
  Effect.sync(() => {
    const attribute = dataAttributeName(name)
    const read = (): string => element.getAttribute(attribute) ?? ''
    const observer = new MutationObserver(() => runCallback(() => onChange(read())))
    observer.observe(element, { attributes: true, attributeFilter: [attribute] })
    return () => observer.disconnect()
  })

// Fires once per subtree mutation with the element nodes that were added and
// removed. Filtering those to interesting roots is a PureScript decision.
export const observeChildList = (
  element: Element,
): (onChange: (delta: ChildListDelta) => Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  onChange =>
  Effect.sync(() => {
    const elementsIn = (node: Node): ReadonlyArray<Element> => {
      if (!(node instanceof Element)) return []
      return [node, ...Array.from(node.querySelectorAll('*'))]
    }
    const observer = new MutationObserver(records => {
      const added: Array<Element> = []
      const removed: Array<Element> = []
      for (const record of records) {
        record.addedNodes.forEach(node => added.push(...elementsIn(node)))
        record.removedNodes.forEach(node => removed.push(...elementsIn(node)))
      }
      runCallback(() => onChange({ added, removed }))
    })
    observer.observe(element, { childList: true, subtree: true })
    return () => observer.disconnect()
  })

export const onImageLoad = (
  image: Element,
): (onLoad: Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  onLoad =>
  Effect.sync(() => {
    const handler = (): void => Effect.runSync(onLoad)
    image.addEventListener('load', handler)
    return () => image.removeEventListener('load', handler)
  })

export const onContextLost = (
  canvas: Element,
): (onLost: Effect.Effect<void>) => Effect.Effect<Cleanup> =>
  onLost =>
  Effect.sync(() => {
    const handler = (): void => Effect.runSync(onLost)
    canvas.addEventListener('webglcontextlost', handler)
    return () => canvas.removeEventListener('webglcontextlost', handler)
  })

export const onWindowResize = (onResize: Effect.Effect<void>): Effect.Effect<Cleanup> =>
  Effect.sync(() => {
    const handler = (): void => Effect.runSync(onResize)
    window.addEventListener('resize', handler)
    return () => window.removeEventListener('resize', handler)
  })

// Runs an Effect-valued visitor over each element, synchronously in order.
// Replaces Data.Foldable's traverse_ (whose class-dictionary wrapper degrades
// to `unknown` in the generated TypeScript).
export const forEach = <A>(
  items: ReadonlyArray<A>,
): (visit: (item: A) => Effect.Effect<void>) => Effect.Effect<void> =>
  visit =>
  Effect.sync(() => {
    for (const item of items) Effect.runSync(visit(item))
  })

export const prefersReducedMotion: Effect.Effect<boolean> = Effect.sync(() =>
  window.matchMedia('(prefers-reduced-motion: reduce)').matches,
)

export const devicePixelRatio: Effect.Effect<number> = Effect.sync(() => window.devicePixelRatio)

export const nowTimestamp: Effect.Effect<number> = Effect.sync(() => performance.now())

// Cryptographically random variant selection for the scribble mount.
export const randomUint32: Effect.Effect<number> = Effect.sync(() => {
  const buffer = new Uint32Array(1)
  crypto.getRandomValues(buffer)
  return buffer[0] ?? 0
})

export const elementBounds = (element: Element): Effect.Effect<Bounds> =>
  Effect.sync(() => {
    const bounds = element.getBoundingClientRect()
    return { width: bounds.width, height: bounds.height }
  })

export const clientSize = (element: Element): Effect.Effect<Bounds> =>
  Effect.sync(() => ({ width: element.clientWidth, height: element.clientHeight }))

export const imageNaturalSize = (image: Element): Effect.Effect<Bounds> =>
  Effect.sync(() => ({
    width: image instanceof HTMLImageElement ? image.naturalWidth : 0,
    height: image instanceof HTMLImageElement ? image.naturalHeight : 0,
  }))

export const imageComplete = (image: Element): Effect.Effect<boolean> =>
  Effect.sync(() => image instanceof HTMLImageElement && image.complete)

export const matchesSelector = (element: Element): (selector: string) => Effect.Effect<boolean> =>
  selector => Effect.sync(() => element.matches(selector))

export const findElement = (scope: Element): (selector: string) => Effect.Effect<ReadonlyArray<Element>> =>
  selector =>
  Effect.sync(() => {
    const found = scope.querySelector(selector)
    return found === null ? [] : [found]
  })

export const selectElements = (scope: Element): (selector: string) => Effect.Effect<ReadonlyArray<Element>> =>
  selector => Effect.sync(() => Array.from(scope.querySelectorAll(selector)))

export const parentElement = (element: Element): Effect.Effect<ReadonlyArray<Element>> =>
  Effect.sync(() => {
    const parent = element.parentElement
    return parent === null ? [] : [parent]
  })

// Pure identity comparison — kept as FFI so PureScript never needs an escape
// hatch for reference equality on opaque Elements.
export const elementsEqual = (left: Element): (right: Element) => boolean => right => left === right

export const readDataAttribute = (element: Element): (name: string) => Effect.Effect<string> =>
  name => Effect.sync(() => element.getAttribute(dataAttributeName(name)) ?? '')

export const writeDataFlag = (
  element: Element,
): (name: string) => (value: boolean) => Effect.Effect<void> =>
  name => value =>
  Effect.sync(() => {
    if (value) element.setAttribute(dataAttributeName(name), 'true')
    else element.removeAttribute(dataAttributeName(name))
  })

export const setAspectRatio = (
  element: Element,
): (width: number) => (height: number) => Effect.Effect<void> =>
  width => height =>
  Effect.sync(() => {
    if (element instanceof HTMLElement) element.style.aspectRatio = `${width} / ${height}`
  })

export const computedStyleValue = (element: Element): (property: string) => Effect.Effect<string> =>
  property => Effect.sync(() => getComputedStyle(element).getPropertyValue(property))
