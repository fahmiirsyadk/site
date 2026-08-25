import { Effect, Schema as S } from 'effect'
import { Render } from 'foldkit'
import { load, pushUrl as navigate } from 'foldkit/navigation'

import { mountDitheredImage } from '../platform/browser/dithered-image.ts'
import { mountHollowMark } from '../platform/browser/hollow-mark.ts'
import { mountRandomScribble } from '../platform/browser/random-scribble.ts'
import { mountSeaShader } from '../platform/browser/shader.ts'

type Cleanup = () => void

type DocumentMetadata = Readonly<{
  title: string
  description: string
  image: string
  contentType: string
}>

const Profile = S.Struct({ followers: S.Number })
const Contributions = S.Struct({
  total: S.Struct({ lastYear: S.Number }),
  contributions: S.Array(S.Struct({ level: S.Number })),
})

const setMeta = (selector: string, attribute: readonly [string, string], value: string): void => {
  const existing = document.head.querySelector(selector)
  const element = existing instanceof HTMLMetaElement ? existing : document.createElement('meta')
  element.setAttribute(attribute[0], attribute[1])
  element.content = value
  if (existing === null) {
    document.head.append(element)
  }
}

export const afterPaint = Render.afterPaint

export const prefersReducedMotion =
  Effect.sync(() => window.matchMedia('(prefers-reduced-motion: reduce)').matches)

export const pushUrl = (url: string) => navigate(url)

export const loadExternal = (href: string) => load(href)

export const loadGitHub = (username: string) =>
  Effect.gen(function* () {
    const [profileResponse, contributionsResponse] = yield* Effect.all([
      Effect.tryPromise(() => fetch(`https://api.github.com/users/${username}`)),
      Effect.tryPromise(() =>
        fetch(`https://github-contributions-api.jogruber.de/v4/${username}?y=last`),
      ),
    ])
    if (!profileResponse.ok || !contributionsResponse.ok) {
      return yield* Effect.fail(new Error('GitHub request failed'))
    }
    const profile = yield* Effect.tryPromise(() => profileResponse.json()).pipe(
      Effect.flatMap(S.decodeUnknownEffect(Profile)),
    )
    const contributionData = yield* Effect.tryPromise(() => contributionsResponse.json()).pipe(
      Effect.flatMap(S.decodeUnknownEffect(Contributions)),
    )
    return {
      contributions: contributionData.total.lastYear,
      followers: profile.followers,
      levels: contributionData.contributions.slice(-56).map(contribution => contribution.level),
    }
  })

export const copyPostLink = (url: string) =>
  Effect.tryPromise(() => navigator.clipboard.writeText(url))

export const readTheme =
  Effect.try(() => {
    const theme = localStorage.getItem('theme') === 'dark' ? 'Dark' : 'Light'
    document.documentElement.classList.toggle('dark', theme === 'Dark')
    document.documentElement.style.colorScheme = theme === 'Dark' ? 'dark' : 'light'
    return theme
  })

export const persistTheme = (theme: string) =>
  Effect.try(() => {
    const dark = theme === 'Dark'
    document.documentElement.classList.toggle('dark', dark)
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light'
    localStorage.setItem('theme', dark ? 'dark' : 'light')
  })

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

const acquire = (loadMount: () => Promise<(element: Element) => Cleanup>, element: Element) =>
  Effect.tryPromise(() => loadMount().then(mount => mount(element)))

export const acquireDitheredImage = (element: Element) =>
  acquire(() => Promise.resolve(mountDitheredImage), element)

export const acquireHollowMark = (element: Element) =>
  acquire(() => Promise.resolve(mountHollowMark), element)

export const acquireRandomScribble = (element: Element) =>
  acquire(() => Promise.resolve(mountRandomScribble), element)

export const acquireSeaShader = (element: Element) =>
  acquire(() => Promise.resolve(mountSeaShader), element)

export const release = (cleanup: Cleanup) => Effect.sync(cleanup)
