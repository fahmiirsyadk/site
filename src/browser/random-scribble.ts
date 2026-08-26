import { scribbleAnimation, selectScribble, variantCount } from 'purescript/Runtime.Scribble/index.ts'

const noop = (): void => undefined

const randomVariant = (previousIndex: number) => {
  const randomValue = new Uint32Array(1)
  crypto.getRandomValues(randomValue)
  return selectScribble(previousIndex, (randomValue[0] ?? 0) % variantCount)
}

export const mountRandomScribble = (element: Element): (() => void) => {
  const path = element.querySelector('[data-random-scribble-path]')
  if (!(path instanceof SVGPathElement)) return noop

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  let disposed = false
  let previousVariantIndex = -1
  let animation: Animation | undefined

  const prepareVariant = (): number => {
    const variant = randomVariant(previousVariantIndex)
    previousVariantIndex = variant.index
    path.setAttribute('d', variant.path)
    const pathLength = path.getTotalLength()
    path.style.strokeDasharray = `${pathLength} ${pathLength}`
    path.style.strokeDashoffset = reduceMotion ? '0' : `${pathLength}`
    path.style.visibility = 'visible'
    return pathLength
  }

  const playNext = (): void => {
    if (disposed || reduceMotion) return
    const pathLength = prepareVariant()
    const plan = scribbleAnimation(pathLength)
    animation = path.animate(
      plan.frames.map(frame => ({ strokeDashoffset: `${frame.dashOffset}`, offset: frame.offset })),
      { duration: plan.duration, easing: plan.easing, fill: plan.fill as FillMode },
    )
    animation.finished.then(() => {
      if (disposed) return
      animation = undefined
      playNext()
    }).catch(noop)
  }

  path.style.visibility = 'hidden'
  if (reduceMotion) {
    prepareVariant()
  } else {
    playNext()
  }

  return () => {
    disposed = true
    animation?.cancel()
  }
}
