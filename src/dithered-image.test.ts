import { Effect } from 'effect'
import { describe, expect, test } from 'vitest'

import { mountDitheredImage } from 'purescript/Platform.Browser.DitheredImage/index.ts'

// The generated PureScript signature types `Cleanup` opaquely (unknown), so the
// teardown function is asserted at the boundary.
// SAFETY: every mount returns Sensors.composeCleanups output — a plain () => void.
const mount = (element: Element): (() => void) =>
  Effect.runSync(mountDitheredImage(element)) as () => void

const container = (markup: string): HTMLElement => {
  const element = document.createElement('div')
  element.innerHTML = markup
  return element
}

const ditherMarkup = (source: string): string =>
  `<span class="dithered-image dithered-image-inline" data-dithered-image><img class="dithered-image-source" data-dithered-source src="${source}" alt=""><canvas data-dithered-canvas></canvas></span>`

// MutationObserver callbacks are delivered as microtasks.
const settle = (): Promise<void> => new Promise(resolve => setTimeout(resolve, 0))

describe('dithered image mounting', () => {
  test('mounts every dithered image inside a subtree', () => {
    const prose = container(
      `<p>${ditherMarkup('/one.png')}</p><p>text</p><p>${ditherMarkup('/two.png')}</p><p>${ditherMarkup('/three.png')}</p>`,
    )

    mount(prose)

    const mounted = prose.querySelectorAll('[data-dithered-image][data-dither-initialized="true"]')
    expect(mounted).toHaveLength(3)
  })

  test('mounts a container that is itself a dithered image', () => {
    const cover = container(ditherMarkup('/cover.png')).firstElementChild
    expect(cover).toBeInstanceOf(HTMLElement)
    if (!(cover instanceof HTMLElement)) {
      throw new Error('Expected the dithered image fixture to be an HTMLElement')
    }

    mount(cover)

    expect(cover.dataset.ditherInitialized).toBe('true')
  })

  test('mounts each image only once across repeated mounts', () => {
    const prose = container(`<p>${ditherMarkup('/one.png')}</p>`)
    const image = prose.querySelector('[data-dithered-image]')

    mount(prose)
    if (image instanceof HTMLElement) image.dataset.ditherFallback = 'checked'
    mount(prose)

    expect(image instanceof HTMLElement ? image.dataset.ditherFallback : '').toBe('checked')
  })

  test('falls back without a WebGL context instead of throwing', () => {
    const prose = container(`<p>${ditherMarkup('/one.png')}</p>`)

    const cleanup = mount(prose)

    expect(prose.querySelector('[data-dither-fallback="true"]')).not.toBeNull()
    expect(() => cleanup()).not.toThrow()
  })

  test('mounts images swapped in by a later innerHTML replacement', async () => {
    const prose = container(`<p>${ditherMarkup('/one.png')}</p>`)
    document.body.append(prose)

    mount(prose)
    prose.innerHTML = `<p>${ditherMarkup('/two.png')}</p><p>${ditherMarkup('/three.png')}</p>`
    await settle()

    const mounted = prose.querySelectorAll('[data-dithered-image][data-dither-initialized="true"]')
    expect(mounted).toHaveLength(2)
  })

  test('stops tracking images removed from the subtree', async () => {
    const prose = container(`<p>${ditherMarkup('/one.png')}</p>`)
    document.body.append(prose)

    const cleanup = mount(prose)
    const removed = prose.querySelector('[data-dithered-image]')
    prose.innerHTML = ''
    await settle()

    expect(removed instanceof HTMLElement ? removed.dataset.ditherInitialized : 'unset').toBeUndefined()
    expect(() => cleanup()).not.toThrow()
  })

  test('stops mounting replacements once cleaned up', async () => {
    const prose = container(`<p>${ditherMarkup('/one.png')}</p>`)
    document.body.append(prose)

    const cleanup = mount(prose)
    cleanup()
    prose.innerHTML = `<p>${ditherMarkup('/two.png')}</p>`
    await settle()

    expect(prose.querySelector('[data-dither-initialized="true"]')).toBeNull()
  })
})
