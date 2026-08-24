import type { RawCommand as PurescriptCommand } from 'purescript/App.Wire.Command/index.ts'
import {
  completedLoadExternal,
  completedNavigateInternal,
  completedPersistTheme,
  completedResetCopyStatus,
  completedResetScroll,
  completedSyncDocumentMetadata,
  failedCopyPostLink,
  failedLoadGitHub,
  failedNavigateInternal,
  loadedTheme,
  startedRouteEntry,
  succeededCopyPostLink,
  succeededLoadGitHub,
  type RawMessage,
} from 'purescript/App.Wire.Message/index.ts'

import { Duration, Effect, Match as M, Schema as S } from 'effect'
import { Command, Render } from 'foldkit'
import { load, pushUrl } from 'foldkit/navigation'

const isRuntimeMessage = (value: unknown): value is RawMessage =>
  typeof value === 'object'
  && value !== null
  && '_tag' in value
  && typeof value._tag === 'string'

const RuntimeMessageSchema = S.declare<RawMessage>(isRuntimeMessage)
type ThemeTag = 'Dark' | 'Light'
type RuntimeCommand =
  | Readonly<{ _tag: 'NavigateInternal'; url: string }>
  | Readonly<{ _tag: 'LoadExternal'; href: string }>
  | Readonly<{ _tag: 'StartRouteEntry' }>
  | Readonly<{ _tag: 'LoadGitHub'; username: string }>
  | Readonly<{ _tag: 'CopyPostLink'; url: string }>
  | Readonly<{ _tag: 'ResetCopyStatus' }>
  | Readonly<{ _tag: 'ReadTheme' }>
  | Readonly<{ _tag: 'PersistTheme'; theme: ThemeTag }>
  | Readonly<{ _tag: 'ResetScroll' }>
  | Readonly<{ _tag: 'SyncDocumentMetadata'; title: string; description: string; image: string; contentType: string }>

const Profile = S.Struct({ followers: S.Number })
const Contributions = S.Struct({
  total: S.Struct({ lastYear: S.Number }),
  contributions: S.Array(S.Struct({ level: S.Number })),
})

const safe = <A extends RawMessage, E, R>(
  effect: Effect.Effect<A, E, R>,
  failure: () => A,
): Effect.Effect<A, never, R> => effect.pipe(Effect.catch(() => Effect.succeed(failure())))

const setMeta = (selector: string, attribute: readonly [string, string], value: string): void => {
  const existing = document.head.querySelector(selector)
  const element = existing instanceof HTMLMetaElement ? existing : document.createElement('meta')
  element.setAttribute(attribute[0], attribute[1])
  element.content = value
  if (existing === null) {
    document.head.append(element)
  }
}

const NavigateInternal = Command.define('NavigateInternal', {
  args: { url: S.String },
  messages: [RuntimeMessageSchema],
  execute: ({ url }) =>
    safe(
      Effect.gen(function* () {
        yield* Render.afterPaint
        const reduceMotion = yield* Effect.sync(() =>
          window.matchMedia('(prefers-reduced-motion: reduce)').matches,
        )
        if (!reduceMotion) {
          yield* Effect.sleep(Duration.millis(250))
        }
        yield* pushUrl(url)
        return completedNavigateInternal
      }),
      () => failedNavigateInternal,
    ),
})

const LoadExternal = Command.define('LoadExternal', {
  args: { href: S.String },
  messages: [RuntimeMessageSchema],
  execute: ({ href }) =>
    safe(
      load(href).pipe(Effect.as(completedLoadExternal)),
      () => completedLoadExternal,
    ),
})

const StartRouteEntry = Command.define('StartRouteEntry', {
  messages: [RuntimeMessageSchema],
  execute: safe(
    Render.afterPaint.pipe(Effect.as(startedRouteEntry)),
    () => startedRouteEntry,
  ),
})

const LoadGitHub = Command.define('LoadGitHub', {
  args: { username: S.String },
  messages: [RuntimeMessageSchema],
  execute: ({ username }) =>
    safe(
      Effect.gen(function* () {
        const [profileResponse, contributionsResponse] = yield* Effect.all([
          Effect.tryPromise(() => fetch(`https://api.github.com/users/${username}`)),
          Effect.tryPromise(() =>
            fetch(`https://github-contributions-api.jogruber.de/v4/${username}?y=last`),
          ),
        ])
        if (!profileResponse.ok || !contributionsResponse.ok) {
          return failedLoadGitHub
        }
        const profile = yield* Effect.tryPromise(() => profileResponse.json()).pipe(
          Effect.flatMap(S.decodeUnknownEffect(Profile)),
        )
        const contributionData = yield* Effect.tryPromise(() => contributionsResponse.json()).pipe(
          Effect.flatMap(S.decodeUnknownEffect(Contributions)),
        )
        return succeededLoadGitHub({
          contributions: contributionData.total.lastYear,
          followers: profile.followers,
          levels: contributionData.contributions.slice(-56).map(contribution => contribution.level),
        })
      }),
      () => failedLoadGitHub,
    ),
})

const CopyPostLink = Command.define('CopyPostLink', {
  args: { url: S.String },
  messages: [RuntimeMessageSchema],
  execute: ({ url }) =>
    safe(
      Effect.tryPromise(() => navigator.clipboard.writeText(url)).pipe(
        Effect.as(succeededCopyPostLink),
      ),
      () => failedCopyPostLink,
    ),
})

const ResetCopyStatus = Command.define('ResetCopyStatus', {
  messages: [RuntimeMessageSchema],
  execute: safe(
    Effect.sleep(Duration.seconds(2)).pipe(Effect.as(completedResetCopyStatus)),
    () => completedResetCopyStatus,
  ),
})

const ReadTheme = Command.define('ReadTheme', {
  messages: [RuntimeMessageSchema],
  execute: safe(
    Effect.sync(() => {
      const theme = localStorage.getItem('theme') === 'dark' ? 'Dark' : 'Light'
      document.documentElement.classList.toggle('dark', theme === 'Dark')
      document.documentElement.style.colorScheme = theme === 'Dark' ? 'dark' : 'light'
      return loadedTheme(theme)
    }),
    () => loadedTheme('Light'),
  ),
})

const PersistTheme = Command.define('PersistTheme', {
  args: { theme: S.Literals(['Dark', 'Light']) },
  messages: [RuntimeMessageSchema],
  execute: ({ theme }) =>
    safe(
      Effect.sync(() => {
        document.documentElement.classList.toggle('dark', theme === 'Dark')
        document.documentElement.style.colorScheme = theme === 'Dark' ? 'dark' : 'light'
        localStorage.setItem('theme', theme === 'Dark' ? 'dark' : 'light')
        return completedPersistTheme
      }),
      () => completedPersistTheme,
    ),
})

const ResetScroll = Command.define('ResetScroll', {
  messages: [RuntimeMessageSchema],
  execute: safe(
    Effect.sync(() => {
      document.getElementById('content-scroll')?.scrollTo({ top: 0, behavior: 'auto' })
      window.scrollTo({ top: 0, behavior: 'auto' })
      return completedResetScroll
    }),
    () => completedResetScroll,
  ),
})

const SyncDocumentMetadata = Command.define('SyncDocumentMetadata', {
  args: {
    title: S.String,
    description: S.String,
    image: S.String,
    contentType: S.String,
  },
  messages: [RuntimeMessageSchema],
  execute: metadata =>
    safe(
      Effect.sync(() => {
        setMeta('meta[name="description"]', ['name', 'description'], metadata.description)
        setMeta('meta[property="og:title"]', ['property', 'og:title'], metadata.title)
        setMeta('meta[property="og:description"]', ['property', 'og:description'], metadata.description)
        setMeta('meta[property="og:image"]', ['property', 'og:image'], metadata.image)
        setMeta('meta[property="og:type"]', ['property', 'og:type'], metadata.contentType)
        setMeta('meta[name="twitter:card"]', ['name', 'twitter:card'], 'summary_large_image')
        setMeta('meta[name="twitter:title"]', ['name', 'twitter:title'], metadata.title)
        setMeta('meta[name="twitter:description"]', ['name', 'twitter:description'], metadata.description)
        setMeta('meta[name="twitter:image"]', ['name', 'twitter:image'], metadata.image)
        return completedSyncDocumentMetadata
      }),
      () => completedSyncDocumentMetadata,
    ),
})

type RuntimeFoldkitCommand = Command.Command<RawMessage, any, any>
const withRuntimeCommand = M.withReturnType<RuntimeFoldkitCommand>()

const toRuntimeCommand = (spec: PurescriptCommand): RuntimeCommand => {
  switch (spec._tag) {
    case 'NavigateInternal':
      return { _tag: 'NavigateInternal', url: spec.url }
    case 'LoadExternal':
      return { _tag: 'LoadExternal', href: spec.href }
    case 'StartRouteEntry':
      return { _tag: 'StartRouteEntry' }
    case 'LoadGitHub':
      return { _tag: 'LoadGitHub', username: spec.username }
    case 'CopyPostLink':
      return { _tag: 'CopyPostLink', url: spec.url }
    case 'ResetCopyStatus':
      return { _tag: 'ResetCopyStatus' }
    case 'ReadTheme':
      return { _tag: 'ReadTheme' }
    case 'PersistTheme':
      if (spec.theme !== 'Dark' && spec.theme !== 'Light') throw new Error(`Invalid PersistTheme value: ${spec.theme}`)
      return { _tag: 'PersistTheme', theme: spec.theme }
    case 'ResetScroll':
      return { _tag: 'ResetScroll' }
    case 'SyncDocumentMetadata':
      return {
        _tag: 'SyncDocumentMetadata',
        title: spec.title,
        description: spec.description,
        image: spec.image,
        contentType: spec.contentType,
      }
    default:
      throw new Error(`Unknown PureScript command: ${spec._tag}`)
  }
}

export const commandImpl = (spec: PurescriptCommand): RuntimeFoldkitCommand =>
  M.value(toRuntimeCommand(spec)).pipe(
    withRuntimeCommand,
    M.tagsExhaustive({
      NavigateInternal: ({ url }) => NavigateInternal({ url }),
      LoadExternal: ({ href }) => LoadExternal({ href }),
      StartRouteEntry: () => StartRouteEntry(),
      LoadGitHub: ({ username }) => LoadGitHub({ username }),
      CopyPostLink: ({ url }) => CopyPostLink({ url }),
      ResetCopyStatus: () => ResetCopyStatus(),
      ReadTheme: () => ReadTheme(),
      PersistTheme: ({ theme }) => PersistTheme({ theme }),
      ResetScroll: () => ResetScroll(),
      SyncDocumentMetadata: metadata => SyncDocumentMetadata(metadata),
    }),
  )
