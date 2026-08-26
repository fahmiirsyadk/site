import { Effect } from 'effect'
import { afterEach, describe, expect, test, vi } from 'vitest'

import {
  activityFromResponses,
  fetchContributions,
  fetchProfile,
} from 'purescript/Platform.GitHub/index.ts'

const jsonResponse = (body: unknown): Response =>
  new Response(JSON.stringify(body), { status: 200 })

const requestFailure = { message: 'GitHub request failed' }

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('GitHub activity calculation', () => {
  test('keeps the latest 56 contribution levels in PureScript', () => {
    const activity = activityFromResponses(
      { followers: 42 },
      {
        total: { lastYear: 123 },
        contributions: Array.from({ length: 60 }, (_, level) => ({ level })),
      },
    )

    expect(activity).toEqual({
      contributions: 123,
      followers: 42,
      levels: Array.from({ length: 56 }, (_, index) => index + 4),
    })
  })

  test('fetches, checks status, and decodes integer fields through the Effect chain', async () => {
    const fetchMock = vi.fn(async () => jsonResponse({ followers: 42 }))
    vi.stubGlobal('fetch', fetchMock)
    const profile = await Effect.runPromise(fetchProfile('faah'))
    expect(profile).toEqual({ followers: 42 })
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.github.com/users/faah',
      expect.objectContaining({ signal: expect.anything() }),
    )

    vi.stubGlobal(
      'fetch',
      vi.fn(async () => jsonResponse({ total: { lastYear: 123 }, contributions: [] })),
    )
    const contributions = await Effect.runPromise(fetchContributions('faah'))
    expect(contributions).toEqual({ total: { lastYear: 123 }, contributions: [] })
  })

  test('maps failed responses and invalid payloads to the typed error', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response('rate limited', { status: 403 })),
    )
    await expect(Effect.runPromise(fetchProfile('faah'))).rejects.toEqual(requestFailure)

    vi.stubGlobal(
      'fetch',
      vi.fn(async () => jsonResponse({ followers: 42.5 })),
    )
    await expect(Effect.runPromise(fetchProfile('faah'))).rejects.toEqual(requestFailure)

    vi.stubGlobal(
      'fetch',
      vi.fn(async () => jsonResponse({ total: { lastYear: 'many' }, contributions: [] })),
    )
    await expect(Effect.runPromise(fetchContributions('faah'))).rejects.toEqual(requestFailure)

    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new Error('network down')
      }),
    )
    await expect(Effect.runPromise(fetchContributions('faah'))).rejects.toEqual(requestFailure)
  })
})
