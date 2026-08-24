import type { Model as RuntimeModel } from 'purescript/App.Update/index.ts'
import type { RawCommand as RuntimeCommand } from 'purescript/App.Wire.Command/index.ts'
import type { RawMessage } from 'purescript/App.Wire.Message/index.ts'

import { Match as M, Schema as S } from 'effect'
import { Command, Runtime } from 'foldkit'
import type { Document, HtmlBuilder } from 'foldkit/html'
import type { UrlRequest } from 'foldkit/navigation'
import type { Url } from 'foldkit/url'
import { toString as urlToString } from 'foldkit/url'

import { commandImpl } from './foldkit-command'

type RawLinkRequest = Readonly<{
  requestTag: 'Internal' | 'External'
  requestUrl: string
  requestHref: string
}>

type RuntimeMessage = RawMessage

type UpdateResult = Readonly<{
  model: RuntimeModel
  commands: ReadonlyArray<RuntimeCommand>
}>

type PurescriptApplication = Readonly<{
  init: (path: string) => UpdateResult
  update: (input: Readonly<{ model: RuntimeModel; message: RuntimeMessage }>) => UpdateResult
  view: (model: RuntimeModel) => (builder: HtmlBuilder<RuntimeMessage>) => Document
  clickedLink: (request: RawLinkRequest) => RuntimeMessage
  changedUrl: (path: string) => RuntimeMessage
  isKnownMessageTag: (tag: string) => boolean
}>

const isRecord = (value: unknown): value is Readonly<Record<string, unknown>> =>
  typeof value === 'object' && value !== null

const isRuntimeModel = (value: unknown): value is RuntimeModel => isRecord(value)
const RuntimeModelSchema = S.declare<RuntimeModel>(isRuntimeModel)

const pathOf = (url: Url): string => url.pathname

const requestOf = (request: UrlRequest): RawLinkRequest =>
  M.value(request).pipe(
    M.withReturnType<RawLinkRequest>(),
    M.tagsExhaustive({
      Internal: ({ url }) => ({
        requestTag: 'Internal',
        requestUrl: urlToString(url),
        requestHref: '',
      }),
      External: ({ href }) => ({
        requestTag: 'External',
        requestUrl: '',
        requestHref: href,
      }),
    }),
  )

type RuntimeCommandInstance = Command.Command<RuntimeMessage, never, never>
const commandsOf = (commands: ReadonlyArray<RuntimeCommand>): ReadonlyArray<RuntimeCommandInstance> =>
  commands.map(command => commandImpl(command) as unknown as RuntimeCommandInstance)

export const startImpl = (app: PurescriptApplication): (() => void) => () => {
  const isKnownRuntimeMessage = (value: unknown): value is RuntimeMessage =>
    isRecord(value)
    && typeof value._tag === 'string'
    && app.isKnownMessageTag(value._tag)
  const RuntimeMessageSchema = S.declare<RuntimeMessage>(isKnownRuntimeMessage)
  const application = Runtime.makeApplication({
    Model: RuntimeModelSchema,
    init: url => {
      const result = app.init(pathOf(url))
      return [result.model, commandsOf(result.commands)]
    },
    update: (model, message) => {
      const result = app.update({ model, message })
      return [result.model, commandsOf(result.commands)]
    },
    view: (model, builder) => app.view(model)(builder),
    container: document.getElementById('root'),
    routing: {
      onUrlRequest: request => app.clickedLink(requestOf(request)),
      onUrlChange: url => app.changedUrl(pathOf(url)),
    },
    devTools: { Message: RuntimeMessageSchema },
  })

  Runtime.run(application)
}
