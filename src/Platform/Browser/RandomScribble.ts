// SVG mechanics for the random scribble. PureScript (RandomScribble.purs) owns
// the variant selection and the play loop — this sibling only touches the DOM:
// preparing the path for a variant and running one Web Animations cycle.
import { Effect } from 'effect'

type Cleanup = () => void

export type ScribbleAnimation = Readonly<{
  frames: ReadonlyArray<Readonly<{ dashOffset: number, offset: number }>>
  duration: number
  easing: string
  fill: string
}>

export const hideScribblePath = (path: Element): void => {
  if (path instanceof SVGElement) path.style.visibility = 'hidden'
}

// Stages one variant on the path and returns its measured length.
export const prepareScribblePath =
  (path: Element): (d: string) => (reduceMotion: boolean) => number =>
  d => reduceMotion => {
    if (!(path instanceof SVGElement && path instanceof SVGGeometryElement)) return 0
    path.setAttribute('d', d)
    const pathLength = path.getTotalLength()
    path.style.strokeDasharray = `${pathLength} ${pathLength}`
    path.style.strokeDashoffset = reduceMotion ? '0' : `${pathLength}`
    path.style.visibility = 'visible'
    return pathLength
  }

// Plays one animation cycle and invokes the PureScript continuation when it
// finishes naturally (cancelling rejects the promise, which is ignored).
export const animateScribble =
  (path: Element): (plan: ScribbleAnimation) => (onFinished: Effect.Effect<void>) =>
  Effect.Effect<Cleanup> =>
  plan => onFinished =>
  Effect.sync(() => {
    const animation = path.animate(
      plan.frames.map(frame => ({ strokeDashoffset: `${frame.dashOffset}`, offset: frame.offset })),
      // SAFETY: fill arrives from Scribble.scribbleAnimation, which only emits valid FillMode values.
      { duration: plan.duration, easing: plan.easing, fill: plan.fill as FillMode },
    )
    animation.finished.then(() => Effect.runSync(onFinished)).catch(() => undefined)
    return () => animation.cancel()
  })
