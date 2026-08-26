import { Effect } from 'effect'

import { mountDitheredImage } from '../browser/dithered-image.ts'
import { mountHollowMark } from '../browser/hollow-mark.ts'
import { mountRandomScribble } from '../browser/random-scribble.ts'
import { mountSeaShader } from '../browser/shader.ts'

type Cleanup = () => void

type DocumentMetadata = Readonly<{
  title: string
  description: string
  image: string
  contentType: string
}>

const setMeta = (selector: string, attribute: readonly [string, string], value: string): void => {
  const existing = document.head.querySelector(selector)
  const element = existing instanceof HTMLMetaElement ? existing : document.createElement('meta')
  element.setAttribute(attribute[0], attribute[1])
  element.content = value
  if (existing === null) {
    document.head.append(element)
  }
}

export const resetScroll =
  Effect.try(() => {
    document.getElementById('content-scroll')?.scrollTo({ top: 0, behavior: 'auto' })
    window.scrollTo({ top: 0, behavior: 'auto' })
  })

export const syncDocumentMetadata = (metadata: DocumentMetadata) =>
  Effect.try(() => {
    setMeta('meta[name="description"]', ['name', 'description'], metadata.description)
    setMeta('meta[property="og:title"]', ['property', 'og:title'], metadata.title)
    setMeta('meta[property="og:description"]', ['property', 'og:description'], metadata.description)
    setMeta('meta[property="og:image"]', ['property', 'og:image'], metadata.image)
    setMeta('meta[property="og:type"]', ['property', 'og:type'], metadata.contentType)
    setMeta('meta[name="twitter:card"]', ['name', 'twitter:card'], 'summary_large_image')
    setMeta('meta[name="twitter:title"]', ['name', 'twitter:title'], metadata.title)
    setMeta('meta[name="twitter:description"]', ['name', 'twitter:description'], metadata.description)
    setMeta('meta[name="twitter:image"]', ['name', 'twitter:image'], metadata.image)
  })

const acquire = (mount: (element: Element) => Cleanup, element: Element) =>
  Effect.try(() => mount(element))

export const acquireDitheredImage = (element: Element) =>
  acquire(mountDitheredImage, element)

export const acquireHollowMark = (element: Element) =>
  acquire(mountHollowMark, element)

export const acquireRandomScribble = (element: Element) =>
  acquire(mountRandomScribble, element)

export const acquireSeaShader = (element: Element) =>
  acquire(mountSeaShader, element)

export const release = (cleanup: Cleanup) => Effect.sync(cleanup)
