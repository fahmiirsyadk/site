import { existsSync } from 'node:fs'
import { resolve } from 'node:path'
import type { Plugin, ResolvedConfig, ViteDevServer } from 'vite'

import { buildPureScript } from './build-purescript.js'

const isPureScriptSource = (file: string, root: string): boolean => {
  const sourceRoot = resolve(root, 'src')
  return (
    file.startsWith(sourceRoot) &&
    (file.endsWith('.purs') ||
      (file.startsWith(resolve(sourceRoot, 'Interop')) && file.endsWith('.ts')))
  )
}

export const pureScript = (): Plugin => {
  let config: ResolvedConfig
  let rebuilding = false
  let queued = false

  const rebuild = (server: ViteDevServer): void => {
    if (rebuilding) {
      queued = true
      return
    }

    rebuilding = true
    const status = buildPureScript()
    rebuilding = false

    if (status === 0) {
      server.ws.send({ type: 'full-reload' })
    }

    if (queued) {
      queued = false
      rebuild(server)
    }
  }

  return {
    name: 'site-purescript',
    enforce: 'pre',
    configResolved(resolved) {
      config = resolved
      if (!existsSync(resolve(config.root, 'output/App.Entry/index.ts'))) {
        const status = buildPureScript()
        if (status !== 0) {
          throw new Error('PureScript compilation failed.')
        }
      }
    },
    configureServer(server) {
      const onChange = (file: string): void => {
        if (isPureScriptSource(file, config.root)) {
          rebuild(server)
        }
      }

      server.watcher.on('add', onChange)
      server.watcher.on('change', onChange)
      return () => {
        server.watcher.off('add', onChange)
        server.watcher.off('change', onChange)
      }
    },
  }
}
