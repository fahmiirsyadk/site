import { describe, expect, test } from 'vitest'

import {
  clampPercent,
  headingScrollTarget,
  progressScrollTarget,
  readingProgress,
  sameGeometry,
} from 'purescript/Runtime.Scroll/index.ts'
import type { Geometry } from 'purescript/Runtime.Scroll/index.ts'

const geometry = (overrides: Partial<Geometry> = {}): Geometry => ({
  scrollTop: 0,
  scrollHeight: 2000,
  clientHeight: 1000,
  rootTop: 0,
  headings: [],
  ...overrides,
})

describe('Reading progress calculation', () => {
  test('reports zero progress for an unscrollable root', () => {
    const snapshot = readingProgress(geometry({ scrollHeight: 1000 }))

    expect(snapshot.progress).toBe(0)
    expect(snapshot.headings).toStrictEqual([])
  })

  test('clamps and rounds the scroll percentage', () => {
    expect(readingProgress(geometry({ scrollTop: -40 })).progress).toBe(0)
    expect(readingProgress(geometry({ scrollTop: 2400 })).progress).toBe(100)
    expect(clampPercent(-12.4)).toBe(0)
    expect(clampPercent(133.7)).toBe(100)
    expect(clampPercent((1 / 3) * 100)).toBe(33)
  })

  test('places heading markers relative to the reading anchor', () => {
    const snapshot = readingProgress(
      geometry({
        scrollTop: 500,
        headings: [
          { id: 'how-it-started', level: 2, top: -350 },
          { id: 'details', level: 3, top: 850 },
        ],
      }),
    )

    expect(snapshot.progress).toBe(50)
    expect(snapshot.headings).toStrictEqual([
      { id: 'how-it-started', level: 2, progress: 0 },
      { id: 'details', level: 3, progress: 100 },
    ])
  })

  test('keeps duplicate heading positions stable', () => {
    const first = readingProgress(
      geometry({
        scrollTop: 250,
        headings: [
          { id: 'how-it-started', level: 2, top: 0 },
          { id: 'how-it-started-2', level: 2, top: 0 },
        ],
      }),
    )
    const second = readingProgress(
      geometry({
        scrollTop: 250.5,
        headings: [
          { id: 'how-it-started', level: 2, top: 0 },
          { id: 'how-it-started-2', level: 2, top: 0 },
        ],
      }),
    )

    const firstPositions = first.headings.map(heading => heading.progress)
    const secondPositions = second.headings.map(heading => heading.progress)

    expect(new Set(firstPositions).size).toBe(1)
    expect(firstPositions).toStrictEqual(secondPositions)
    expect(sameGeometry(geometry({ scrollTop: 250 }), geometry({ scrollTop: 250 }))).toBe(true)
  })

  test('detects changed and unchanged measurement snapshots', () => {
    const base = geometry({
      scrollTop: 300,
      headings: [{ id: 'details', level: 3, top: 120 }],
    })

    expect(sameGeometry(base, geometry({ ...base }))).toBe(true)
    expect(sameGeometry(base, geometry({ ...base, scrollTop: 301 }))).toBe(false)
    expect(
      sameGeometry(base, geometry({ ...base, headings: [...base.headings] })),
    ).toBe(true)
    expect(
      sameGeometry(base, geometry({ ...base, headings: [{ id: 'other', level: 2, top: 120 }] })),
    ).toBe(false)
  })
})

describe('Scroll target arithmetic', () => {
  test('lands headings above the viewport anchor offset', () => {
    expect(headingScrollTarget({ scrollTop: 400, rootTop: -50, headingTop: 300 })).toBe(622)
  })

  test('maps percentages onto clamped scroll offsets', () => {
    expect(progressScrollTarget({ range: 900, percent: 50 })).toBe(450)
    expect(progressScrollTarget({ range: 900, percent: -5 })).toBe(0)
    expect(progressScrollTarget({ range: 900, percent: 150 })).toBe(900)
    expect(progressScrollTarget({ range: 0, percent: 80 })).toBe(0)
  })
})
