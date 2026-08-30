import { Effect, Schema as S } from 'effect'

import { schemas } from 'purescript/Domain.GitHub/index.ts'
import type { Contributions, Profile } from 'purescript/Domain.GitHub/index.ts'

export const fetchImpl = (url: string, signal: AbortSignal): Promise<Response> =>
  fetch(url, { signal })

export const okStatusImpl = (response: Response): boolean => response.ok

export const bodyJsonImpl = async (response: Response): Promise<S.Json> =>
  S.decodeUnknownSync(S.Json)(await response.json())

export const decodeProfileImpl = (
  payload: S.Json,
): Effect.Effect<Profile, S.SchemaError> =>
  S.decodeUnknownEffect(schemas.Profile)(payload)

export const decodeContributionsImpl = (
  payload: S.Json,
): Effect.Effect<Contributions, S.SchemaError> =>
  Effect.map(S.decodeUnknownEffect(schemas.Contributions)(payload), data => ({
    ...data,
    contributions: [...data.contributions],
  }))
