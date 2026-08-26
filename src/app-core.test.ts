import { describe, expect, test } from 'vitest'

import {
  ChangedUrl,
  ClickedCopyPostLink,
  ClickedInternalLink,
  GotHomeMessage,
  GotPostMessage,
  StartedRouteEntry,
} from 'purescript/App.Message/index.ts'
import { init, routeMotionName, update } from 'purescript/App.Update/index.ts'
import { routePath } from 'purescript/App.Route/index.ts'
import {
  HoveredLab,
  LeftLab,
  SucceededLoadGitHub,
} from 'purescript/Page.Home.Message/index.ts'
import {
  ChangedReadingProgress,
  MoveProgress,
  SetProgress,
  SucceededCopyLink,
} from 'purescript/Page.Post.Message/index.ts'

describe('PureScript application core', () => {
  test('initializes the route model and direct Foldkit commands in PureScript', () => {
    const initialized = init('/thought/')

    expect(routePath(initialized.model.route)).toBe('/thought/')
    expect(initialized.commands.map(command => command.name)).toStrictEqual([
      'ReadTheme',
      'LoadGitHub',
      'SyncDocumentMetadata',
    ])
    expect(initialized.commands.at(-1)).toMatchObject({
      name: 'SyncDocumentMetadata',
      args: { title: 'Faah', contentType: 'website' },
    })
  })

  test('updates route state and emits direct Foldkit commands', () => {
    const initialized = init('/')
    const updated = update(initialized.model, ChangedUrl({ path: '/lab/', hash: { _tag: 'Nothing' } }))

    expect(routePath(updated.model.route)).toBe('/lab/')
    expect(routeMotionName(updated.model)).toBe('entering')
    expect(updated.commands.map(command => command.name)).toStrictEqual([
      'StartRouteEntry',
      'ResetScroll',
      'SyncDocumentMetadata',
    ])
    expect(updated.commands.at(-1)).toMatchObject({
      name: 'SyncDocumentMetadata',
      args: { title: 'Faah', contentType: 'website' },
    })
  })

  test('completes route motion after the render barrier', () => {
    const initialized = init('/')
    const leaving = update(initialized.model, ClickedInternalLink({ path: '/thought/', hash: { _tag: 'Nothing' } }))
    const completed = update(leaving.model, StartedRouteEntry)

    expect(routeMotionName(leaving.model)).toBe('leaving')
    expect(routeMotionName(completed.model)).toBe('idle')
  })

  test('keeps same-page hash navigation in the Foldkit command model', () => {
    const initialized = init('/thought/chaotic-pendulum/')
    const requested = update(
      initialized.model,
      ClickedInternalLink({
        path: '/thought/chaotic-pendulum/',
        hash: { _tag: 'Just', _1: 'how-it-started' },
      }),
    )

    expect(requested.commands).toStrictEqual([
      expect.objectContaining({
        name: 'NavigateHeading',
        args: { path: '/thought/chaotic-pendulum/', heading: 'how-it-started' },
      }),
    ])

    const changed = update(
      initialized.model,
      ChangedUrl({
        path: '/thought/chaotic-pendulum/',
        hash: { _tag: 'Just', _1: 'how-it-started' },
      }),
    )
    expect(changed.commands).toStrictEqual([
      expect.objectContaining({ name: 'ScrollToHeading', args: { heading: 'how-it-started' } }),
    ])
  })

  test('delegates Home and Post state transitions to their page updates', () => {
    const initialized = init('/')
    const loadedHome = update(
      initialized.model,
      GotHomeMessage(SucceededLoadGitHub({ contributions: 12, followers: 3, levels: [1, 2, 3] })),
    )

    expect(loadedHome.model.home.status._tag).toBe('Ready')

    const hoveredLab = update(loadedHome.model, GotHomeMessage(HoveredLab))
    expect(hoveredLab.model.home.labInteraction._tag).toBe('LabHovered')

    const leftLab = update(hoveredLab.model, GotHomeMessage(LeftLab))
    expect(leftLab.model.home.labInteraction._tag).toBe('LabIdle')

    const requestedCopy = update(leftLab.model, ClickedCopyPostLink('/thought/example/'))
    expect(requestedCopy.commands.map(command => command.name)).toStrictEqual(['CopyPostLink'])

    const copiedPost = update(requestedCopy.model, GotPostMessage(SucceededCopyLink))
    expect(copiedPost.model.post.copyStatus._tag).toBe('Copied')
    expect(copiedPost.commands.map(command => command.name)).toStrictEqual(['ResetCopyStatus'])
  })

  test('clamps progress commands to the reading range', () => {
    const initialized = init('/thought/chaotic-pendulum/')
    const movedBeyondTop = update(
      initialized.model,
      GotPostMessage(MoveProgress(-30)),
    )
    expect(movedBeyondTop.commands).toStrictEqual([
      expect.objectContaining({ name: 'ScrollToProgress', args: { progress: 0 } }),
    ])

    const withProgress = update(
      movedBeyondTop.model,
      GotPostMessage(ChangedReadingProgress({ progress: 80, headings: [] })),
    )
    const movedBeyondBottom = update(withProgress.model, GotPostMessage(MoveProgress(45)))
    expect(movedBeyondBottom.commands).toStrictEqual([
      expect.objectContaining({ name: 'ScrollToProgress', args: { progress: 100 } }),
    ])

    const setDirectly = update(withProgress.model, GotPostMessage(SetProgress(140)))
    expect(setDirectly.commands).toStrictEqual([
      expect.objectContaining({ name: 'ScrollToProgress', args: { progress: 100 } }),
    ])
  })
})
