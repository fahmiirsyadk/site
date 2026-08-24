import { describe, expect, test } from 'vitest'

import { rasterLayout } from 'purescript/Runtime.Canvas/index.ts'
import {
  bayerMatrix,
  ditherColor,
  ditherLayout,
  quadVertices,
  shouldDrawFrame,
} from 'purescript/Runtime.Dither/index.ts'
import {
  beginHollowDrag,
  dragHollow,
  endHollowDrag,
  hollowCubeRotation,
  hollowDragValues,
  initialHollowMotion,
  initialHollowVisual,
  stepHollowVisual,
  stepHollowMotion,
} from 'purescript/Runtime.HollowMotion/index.ts'
import { frameTiming } from 'purescript/Runtime.Frame/index.ts'
import {
  initialSeaMotion,
  retargetSeaMotion,
  seaDragTarget,
  stepSeaMotion,
} from 'purescript/Runtime.SeaMotion/index.ts'
import {
  hollowVertexCount,
  hollowVertices,
} from 'purescript/Runtime.HollowGeometry/index.ts'
import {
  scribbleAnimation,
  selectScribble,
  variantCount,
} from 'purescript/Runtime.Scribble/index.ts'

describe('PureScript runtime calculations', () => {
  test('owns shared animation frame timing', () => {
    expect(frameTiming({ timestamp: 2500, previousTimestamp: 2400, startedAt: 500 })).toEqual({
      seconds: 2,
      frameDuration: 40,
      intro: 1,
    })
  })

  test('clamps and eases sea interaction state', () => {
    const pointerTarget = seaDragTarget({
      baseX: 0,
      baseY: 2,
      startX: 0,
      startY: 0,
      currentX: 50,
      currentY: 25,
      width: 100,
      height: 100,
    })
    const targeted = retargetSeaMotion({ x: 20, y: -4 }, initialSeaMotion)
    const stepped = stepSeaMotion({ dragging: true, frameDuration: 16, labHoverTarget: 1 }, targeted)

    expect(pointerTarget).toEqual({ x: 5, y: 0 })
    expect(targeted.targetX).toBe(7)
    expect(targeted.targetY).toBe(0)
    expect(stepped.smoothX).toBeGreaterThan(0)
    expect(stepped.labHover).toBeGreaterThan(0)
  })

  test('owns hollow drag inertia and settling', () => {
    const dragValues = hollowDragValues({
      dragStartAngle: 0,
      dragStartX: 0,
      currentX: 50,
      previousX: 40,
      width: 100,
      elapsed: 10,
    })
    const started = beginHollowDrag(initialHollowMotion)
    const dragged = dragHollow({ angle: Math.PI * 0.75, velocity: 0.004 }, started)
    const released = endHollowDrag({ stale: false }, dragged)
    const frames: ReadonlyArray<number> = Array.from({ length: 800 }, (_, index) => index)
    const settled = frames.reduce<typeof released>(
      motion => stepHollowMotion({ dragging: false, frameDuration: 16, reduceMotion: false }, motion),
      released,
    )

    expect(dragValues.angle).toBeCloseTo(Math.PI)
    expect(dragValues.velocity).toBeCloseTo(Math.PI / 50)
    expect(settled.snapping).toBe(false)
    expect(settled.interactionActive).toBe(false)
    expect(settled.targetAngle % (Math.PI * 2)).toBeCloseTo(0)
  })

  test('owns hollow visual easing and cube rotation', () => {
    const visual = stepHollowVisual({
      frameDuration: 100,
      labHoverTarget: 1,
      interactionActive: false,
      reduceMotion: false,
    }, initialHollowVisual(0))

    expect(visual.labHover).toBeCloseTo(0.3)
    expect(visual.motionSeconds).toBeCloseTo(0.1)
    expect(hollowCubeRotation({ elapsed: 2, reduceMotion: false })).toBeCloseTo(1.8)
    expect(hollowCubeRotation({ elapsed: 2, reduceMotion: true })).toBe(0.48)
  })

  test('calculates clamped high-DPI canvas dimensions', () => {
    expect(rasterLayout({
      width: 100.4,
      height: 50.4,
      devicePixelRatio: 4,
      minimumPixelRatio: 1,
      maximumPixelRatio: 2,
    })).toEqual({
      canvasWidth: 201,
      canvasHeight: 101,
      cssWidth: 100,
      cssHeight: 50,
      pixelRatio: 2,
    })
  })

  test('owns dither color, Bayer data, layout, and frame decisions', () => {
    const color = ditherColor('#f4c')
    const layout = ditherLayout({
      width: 100,
      height: 50,
      devicePixelRatio: 3,
      sourceWidth: 100,
      sourceHeight: 100,
    })

    expect(color.red).toBe(1)
    expect(color.green).toBeCloseTo(68 / 255)
    expect(color.blue).toBeCloseTo(204 / 255)
    expect(ditherColor('invalid')).toMatchObject({ red: 1 })
    expect(bayerMatrix).toHaveLength(16)
    expect(quadVertices).toHaveLength(8)
    expect(layout).toEqual({
      canvasWidth: 200,
      canvasHeight: 100,
      cssWidth: 100,
      cssHeight: 50,
      textureCoordinates: [0, 0.25, 1, 0.25, 0, 0.75, 1, 0.75],
    })
    expect(shouldDrawFrame({ reduceMotion: false, timestamp: 49, previousTimestamp: 0 })).toBe(false)
    expect(shouldDrawFrame({ reduceMotion: false, timestamp: 50, previousTimestamp: 0 })).toBe(true)
    expect(shouldDrawFrame({ reduceMotion: true, timestamp: 0, previousTimestamp: 0 })).toBe(true)
  })

  test('generates the complete hollow mesh in PureScript', () => {
    expect(hollowVertexCount).toBe(43_812)
    expect(hollowVertices).toHaveLength(hollowVertexCount * 7)
  })

  test('selects a different valid scribble when random choice repeats', () => {
    const selected = selectScribble(2, 2)
    const animation = scribbleAnimation(120)

    expect(variantCount).toBe(4)
    expect(selected.index).toBe(3)
    expect(selected.path.startsWith('M')).toBe(true)
    expect(animation.frames.map(frame => frame.dashOffset)).toEqual([120, 0, 0, -120])
    expect(animation.duration).toBe(2800)
  })
})
