import { describe, test } from 'vitest'

import {
  CompletedMountHollowMark,
  CompletedMountRandomScribble,
  CompletedMountSeaShader,
  CompletedScrollToProgress,
  type Message,
} from 'purescript/App.Message/index.ts'
import { scrollToProgress } from 'purescript/App.Command/index.ts'
import {
  ditheredImage,
  hollowMark,
  randomScribble,
  seaShader,
  trackPostProgress,
} from 'purescript/App.Mount/index.ts'
import type { Model } from 'purescript/App.Update/index.ts'
import { init, update } from 'purescript/App.Update/index.ts'
import { view } from 'purescript/App.View/index.ts'
import { renderDocumentForTest } from 'purescript-foldkit/runtime'
import {
  ChangedReadingProgress,
  CompletedMountDitheredImage,
} from 'purescript/Page.Post.Message/index.ts'

import type { Document, HtmlBuilder } from 'foldkit/html'
import * as Scene from 'foldkit/scene'

const render = (model: Model, builder: HtmlBuilder<Message>): Document => {
  return renderDocumentForTest(view(model), builder)
}

const resolveHomeMounts = Scene.Mount.resolveAll(
  [hollowMark, CompletedMountHollowMark],
  [randomScribble, CompletedMountRandomScribble],
  [seaShader, CompletedMountSeaShader],
)

const resolvePageMounts = Scene.Mount.resolveAll(
  [hollowMark, CompletedMountHollowMark],
  [seaShader, CompletedMountSeaShader],
)

const resolvePostMounts = Scene.Mount.resolveAll(
  [hollowMark, CompletedMountHollowMark],
  [ditheredImage, CompletedMountDitheredImage],
  [ditheredImage, CompletedMountDitheredImage],
  [seaShader, CompletedMountSeaShader],
  [trackPostProgress, ChangedReadingProgress({ progress: 0, headings: [] })],
)

describe('application view integration', () => {
  test('renders shared navigation and published thought content on the home page', () => {
    Scene.scene(
      { update, view: render },
      Scene.given(init('/').model),
      Scene.expect(Scene.role('navigation', { name: 'Primary navigation' })).toExist(),
      Scene.expect(Scene.role('link', { name: 'thought' })).toHaveAttr('href', '/thought/'),
      Scene.expect(Scene.text('Chaotic pendulum')).toExist(),
      resolveHomeMounts,
    )
  })

  test('keeps shared chrome while rendering the thought route', () => {
    Scene.scene(
      { update, view: render },
      Scene.given(init('/thought/').model),
      Scene.expect(Scene.role('img', { name: 'Faah split lunar sphere' })).toExist(),
      Scene.expect(Scene.role('heading', { name: 'thought' })).toExist(),
      Scene.expect(Scene.role('link', { name: 'thought' })).toHaveAttr('aria-current', 'page'),
      Scene.expect(Scene.text('Chaotic pendulum')).toExist(),
      resolvePageMounts,
    )
  })

  test('renders a thought page through the Foldkit submodel boundary', () => {
    Scene.scene(
      { update, view: render },
      Scene.given(init('/thought/chaotic-pendulum/').model),
      Scene.expect(Scene.role('heading', { name: 'Chaotic pendulum' })).toExist(),
      Scene.expect(Scene.role('slider', { name: 'Reading progress' })).toHaveAttr('aria-valuetext', '0% read'),
      resolvePostMounts,
    )
  })

  test('clicking a progress tick dispatches the matching scroll command', () => {
    Scene.scene(
      { update, view: render },
      Scene.given(init('/thought/chaotic-pendulum/').model),
      resolvePostMounts,
      Scene.click(Scene.selector('[data-reading-progress-tick="50"]')),
      Scene.expectHandled(),
      Scene.Command.resolve(scrollToProgress(50), CompletedScrollToProgress),
    )
  })

  test('keyboard interaction on the slider clamps to the progress range', () => {
    Scene.scene(
      { update, view: render },
      Scene.given(init('/thought/chaotic-pendulum/').model),
      resolvePostMounts,
      Scene.keydown(Scene.role('slider', { name: 'Reading progress' }), 'End'),
      Scene.expectHandled(),
      Scene.Command.resolve(scrollToProgress(100), CompletedScrollToProgress),
    )
  })

  test('preserves the monochrome lab interaction state on the lab route', () => {
    Scene.scene(
      { update, view: render },
      Scene.given(init('/lab/').model),
      Scene.expect(Scene.role('heading', { name: 'lab' })).toExist(),
      Scene.expect(Scene.role('img', { name: 'Faah split lunar sphere' })).toHaveAttr(
        'data-lab-interaction',
        'hovered',
      ),
      Scene.expect(Scene.selector('#sea-footer')).toHaveAttr('data-lab-interaction', 'hovered'),
      resolvePageMounts,
    )
  })
})
