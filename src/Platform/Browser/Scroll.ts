import { Effect, Queue, Schema as S, Stream } from 'effect'
import {
  headingScrollTarget,
  progressScrollTarget,
  sameGeometry,
} from 'purescript/Runtime.Scroll/index.ts'
import type { Geometry } from 'purescript/Runtime.Scroll/index.ts'

const TrackHeadingsArgs = S.Struct({
  scrollRootSelector: S.String,
  layoutSelector: S.String,
  contentSelector: S.String,
  headingSelector: S.String,
})
type TrackHeadingsArgs = typeof TrackHeadingsArgs.Type

const resolveElement = (selector: string, scope: ParentNode): HTMLElement | null => {
  const value = scope.querySelector(selector)
  return value instanceof HTMLElement ? value : null
}

const measureGeometry = (
  root: HTMLElement,
  content: HTMLElement,
  selector: string,
): Geometry => ({
  scrollTop: root.scrollTop,
  scrollHeight: root.scrollHeight,
  clientHeight: root.clientHeight,
  rootTop: root.getBoundingClientRect().top,
  headings: Array.from(content.querySelectorAll<HTMLElement>(selector))
    .filter(heading => heading.id.length > 0)
    .map(heading => ({
      id: heading.id,
      level: Number(heading.tagName.slice(1)),
      top: heading.getBoundingClientRect().top,
    })),
})

export const trackReadingStreamImpl = <Message>(
  element: Element,
  rawArgs: TrackHeadingsArgs,
  onChanged: (geometry: Geometry) => Message,
  onFailure: (reason: string) => Message,
): Stream.Stream<Message> => {
  const args = S.decodeUnknownSync(TrackHeadingsArgs)(rawArgs)
  return Stream.callback(queue =>
    Effect.gen(function* () {
      const layout = element.closest(args.layoutSelector)
      const root =
        element.closest<HTMLElement>(args.scrollRootSelector) ??
        resolveElement(args.scrollRootSelector, document)
      const content = layout === null ? null : resolveElement(args.contentSelector, layout)

      if (root === null || content === null) {
        const reason =
          root === null
            ? `TrackPostProgress found no scroll root for ${args.scrollRootSelector}`
            : `TrackPostProgress found no post content for ${args.contentSelector} inside ${args.layoutSelector}`
        yield* Effect.sync(() => Queue.offerUnsafe(queue, onFailure(reason)))
        return yield* Effect.never
      }

      let previous: Geometry | null = null
      const emit = () => {
        const geometry = measureGeometry(root, content, args.headingSelector)
        if (previous !== null && sameGeometry(previous, geometry)) return
        previous = geometry
        Queue.offerUnsafe(queue, onChanged(geometry))
      }

      yield* Effect.acquireRelease(
        Effect.sync(() => {
          const onScroll = () => emit()
          const observer = new ResizeObserver(() => emit())
          root.addEventListener('scroll', onScroll, { passive: true })
          observer.observe(root)
          observer.observe(content)
          return { onScroll, observer }
        }),
        ({ onScroll, observer }) =>
          Effect.sync(() => {
            root.removeEventListener('scroll', onScroll)
            observer.disconnect()
          }),
      )

      yield* Effect.sync(emit)
      return yield* Effect.never
    }),
  )
}

export const scrollToHeadingImpl = (
  rootSelector: string,
  headingId: string,
  smooth: boolean,
): Effect.Effect<void> =>
  Effect.sync(() => {
    const root = resolveElement(rootSelector, document)
    const heading = document.getElementById(headingId)
    if (root === null || heading === null) return

    root.scrollTo({
      top: headingScrollTarget({
        scrollTop: root.scrollTop,
        rootTop: root.getBoundingClientRect().top,
        headingTop: heading.getBoundingClientRect().top,
      }),
      behavior: smooth ? 'smooth' : 'auto',
    })
    heading.focus({ preventScroll: true })
  })

export const scrollToProgressImpl = (
  rootSelector: string,
  progress: number,
  smooth: boolean,
): Effect.Effect<void> =>
  Effect.sync(() => {
    const root = resolveElement(rootSelector, document)
    if (root === null) return

    root.scrollTo({
      top: progressScrollTarget({
        range: Math.max(0, root.scrollHeight - root.clientHeight),
        percent: progress,
      }),
      behavior: smooth ? 'smooth' : 'auto',
    })
  })
