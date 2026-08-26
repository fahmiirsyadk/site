import { Effect, Schema as S } from 'effect'

import type { Contributions, Profile } from 'purescript/Domain.GitHub/index.ts'

const ProfileSchema = S.Struct({ followers: S.Int })
const ContributionsSchema = S.Struct({
  total: S.Struct({ lastYear: S.Int }),
  contributions: S.Array(S.Struct({ level: S.Int })),
})

export const fetchImpl = (url: string, signal: AbortSignal): Promise<Response> =>
  fetch(url, { signal })

export const okStatusImpl = (response: Response): boolean => response.ok

export const bodyJsonImpl = (response: Response): Promise<unknown> => response.json()

export const decodeProfileImpl = (payload: unknown): Effect.Effect<Profile, unknown> =>
  S.decodeUnknownEffect(ProfileSchema)(payload)

export const decodeContributionsImpl = (
  payload: unknown,
): Effect.Effect<Contributions, unknown> =>
  Effect.map(S.decodeUnknownEffect(ContributionsSchema)(payload), data => ({
    ...data,
    contributions: [...data.contributions],
  }))
