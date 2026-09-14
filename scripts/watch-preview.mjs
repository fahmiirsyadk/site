// Production-parity live preview.
//
// The counterpart to `make watch`: instead of a GHCi browser session, every
// change runs the real `make build` (never `make update` or `wasm-opt`) and
// re-renders `public/`, so what the browser shows is the prerendered output
// the deploy path produces. CSS edits take a fast path that only reruns
// Tailwind and copies the stylesheet into `public/`.
//
// Start it with `make watch-preview` from the repository root. The HTTP
// server it starts stays on the project's port 8080; refresh the browser
// after each cycle (there is no injected reload client).
import { spawn } from 'node:child_process'
import { copyFileSync, watch } from 'node:fs'
import { join } from 'node:path'

const WATCH_DIRS = [
  'content',
  'content-core',
  'content-compiler',
  'scripts/content',
  'shaders',
  'styles',
  'src',
  'app',
  'static',
]
const DEBOUNCE_MS = 300
const PORT = '8080'

let busy = false
let timer = null
const pending = new Set()

const banner = () => {
  console.log(`[preview] serving http://127.0.0.1:${PORT} (refresh after each rebuild)`)
}

const run = (label, command, args) =>
  new Promise(resolve => {
    const started = Date.now()
    console.log(`[preview] ${label}...`)
    const child = spawn(command, args, { stdio: 'inherit' })
    child.on('exit', code => {
      const seconds = ((Date.now() - started) / 1000).toFixed(1)
      const verb = code === 0 ? 'done' : `failed (${code})`
      console.log(`[preview] ${label} ${verb} in ${seconds}s`)
      resolve()
    })
  })

const rebuild = async paths => {
  const stylesOnly = paths.every(path => path.startsWith('styles/'))
  if (stylesOnly) {
    await run('css', 'make', ['css'])
    copyFileSync('static/styles.css', 'public/styles.css')
    return
  }
  await run('build + prerender', 'make', ['build', 'prerender'])
}

const pump = async () => {
  timer = null
  if (busy) return
  busy = true
  while (pending.size > 0) {
    const paths = [...pending]
    pending.clear()
    await rebuild(paths)
  }
  busy = false
}

const schedule = path => {
  pending.add(path)
  if (timer) clearTimeout(timer)
  timer = setTimeout(pump, DEBOUNCE_MS)
}

const server = spawn('http-server', ['public', '-p', PORT, '-c-1'], { stdio: 'inherit' })
server.on('exit', code => process.exit(code ?? 0))

// Keep every watcher referenced for the lifetime of the process. An
// unreferenced FSWatcher can be collected and then silently stops reporting.
const watchers = []
for (const dir of WATCH_DIRS) {
  try {
    const watcher = watch(dir, { recursive: true }, (_event, filename) => {
      const path = filename ? join(dir, filename.toString()) : dir
      if (/(~|\.swp$|^\.#)/.test(path)) return
      schedule(path)
    })
    watcher.on('error', error => console.error(`[preview] watch error in ${dir}: ${error.message}`))
    watchers.push(watcher)
  } catch (error) {
    console.error(`[preview] cannot watch ${dir}: ${error.message}`)
  }
}

banner()
await run('initial build + prerender', 'make', ['build', 'prerender'])
console.log('[preview] watching for changes')
