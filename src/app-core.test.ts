import { describe, expect, test } from 'vitest'

import {
  ChangedUrl,
  ClickedCopyPostLink,
  ClickedInternalLink,
  FailedNavigateInternal,
  GotHomeMessage,
  GotPostMessage,
} from 'purescript/App.Message/index.ts'
import { init, routeMotionName, update } from 'purescript/App.Update/index.ts'
import { routePath } from 'purescript/App.Route/index.ts'
import {
  HoveredLab,
  LeftLab,
  SucceededLoadGitHub,
} from 'purescript/Page.Home.Message/index.ts'
import { SucceededCopyLink } from 'purescript/Page.Post.Message/index.ts'

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
    const updated = update(initialized.model, ChangedUrl('/lab/'))

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

  test('recovers route motion when internal navigation fails', () => {
    const initialized = init('/')
    const leaving = update(initialized.model, ClickedInternalLink('/thought/'))
    const recovered = update(leaving.model, FailedNavigateInternal)

    expect(routeMotionName(leaving.model)).toBe('leaving')
    expect(routeMotionName(recovered.model)).toBe('idle')
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
})
