import { Effect, Schema as S } from 'effect'
import { define } from 'foldkit/mount'
import {
  completedMountDitheredImage,
  completedMountHollowMark,
  completedMountRandomScribble,
  completedMountSeaShader,
  type RawMessage,
} from 'purescript/App.Wire.Message/index.ts'

const messageSchema = S.declare<RawMessage>(
  (value): value is RawMessage => typeof value === 'object' && value !== null && '_tag' in value,
)

const ditheredImageDefinition = define('DitheredImage', messageSchema)(element =>
  Effect.acquireRelease(
    Effect.tryPromise(() => import('./dithered-image')).pipe(
      Effect.map(module => module.mountDitheredImage(element)),
    ),
    cleanup => Effect.sync(cleanup),
  ).pipe(
    Effect.as(completedMountDitheredImage),
    Effect.catch(() => Effect.succeed(completedMountDitheredImage)),
  ),
)

export const ditheredImage = ditheredImageDefinition()

const hollowMarkDefinition = define('HollowMark', messageSchema)(element =>
  Effect.acquireRelease(
    Effect.tryPromise(() => import('./hollow-mark')).pipe(
      Effect.map(module => module.mountHollowMark(element)),
    ),
    cleanup => Effect.sync(cleanup),
  ).pipe(
    Effect.as(completedMountHollowMark),
    Effect.catch(() => Effect.succeed(completedMountHollowMark)),
  ),
)

export const hollowMark = hollowMarkDefinition()

const randomScribbleDefinition = define('RandomScribble', messageSchema)(element =>
  Effect.acquireRelease(
    Effect.tryPromise(() => import('./random-scribble')).pipe(
      Effect.map(module => module.mountRandomScribble(element)),
    ),
    cleanup => Effect.sync(cleanup),
  ).pipe(
    Effect.as(completedMountRandomScribble),
    Effect.catch(() => Effect.succeed(completedMountRandomScribble)),
  ),
)

export const randomScribble = randomScribbleDefinition()

const seaShaderDefinition = define('SeaShader', messageSchema)(element =>
  Effect.acquireRelease(
    Effect.tryPromise(() => import('./shader')).pipe(
      Effect.map(module => module.mountSeaShader(element)),
    ),
    cleanup => Effect.sync(cleanup),
  ).pipe(
    Effect.as(completedMountSeaShader),
    Effect.catch(() => Effect.succeed(completedMountSeaShader)),
  ),
)

export const seaShader = seaShaderDefinition()
