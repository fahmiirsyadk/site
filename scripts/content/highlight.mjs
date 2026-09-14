// Build-time highlight.js adapter. The native content compiler sends one
// batch of code blocks and receives only structured text/span nodes.
import hljs from 'highlight.js/lib/core'
import bash from 'highlight.js/lib/languages/bash'
import haskell from 'highlight.js/lib/languages/haskell'
import ini from 'highlight.js/lib/languages/ini'
import javascript from 'highlight.js/lib/languages/javascript'
import json from 'highlight.js/lib/languages/json'

hljs.registerLanguage('bash', bash)
hljs.registerLanguage('haskell', haskell)
hljs.registerLanguage('ini', ini)
hljs.registerLanguage('javascript', javascript)
hljs.registerLanguage('json', json)

const LANGUAGE_ALIASES = { purescript: 'haskell', toml: 'ini' }

const decodeEntities = value => value.replace(/&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);/g, (whole, entity) => {
  if (entity.startsWith('#x')) return String.fromCodePoint(Number.parseInt(entity.slice(2), 16))
  if (entity.startsWith('#')) return String.fromCodePoint(Number.parseInt(entity.slice(1), 10))
  switch (entity) {
    case 'amp': return '&'
    case 'lt': return '<'
    case 'gt': return '>'
    case 'quot': return '"'
    case 'apos': return '\''
    default: return whole
  }
})

const parseHighlight = html => {
  const root = []
  const stack = [root]
  const pattern = /<span class="([^"]*)">|<\/span>|([^<]+)/g
  let match
  while ((match = pattern.exec(html)) !== null) {
    if (match[1] !== undefined) {
      const span = { kind: 'span', className: match[1], children: [] }
      stack[stack.length - 1].push(span)
      stack.push(span.children)
    } else if (match[0] === '</span>') {
      stack.pop()
    } else {
      const value = decodeEntities(match[2])
      if (value !== '') stack[stack.length - 1].push({ kind: 'text', value })
    }
  }
  return root
}

const highlight = (code, language) => {
  const requested = (language ?? '').toLowerCase()
  const name = LANGUAGE_ALIASES[requested] ?? requested
  if (name === '' || name === 'text' || name === 'plaintext' || !hljs.getLanguage(name)) {
    return [{ kind: 'text', value: code }]
  }
  return parseHighlight(hljs.highlight(code, { language: name, ignoreIllegals: true }).value)
}

const source = await new Promise((resolve, reject) => {
  let value = ''
  process.stdin.setEncoding('utf8')
  process.stdin.on('data', chunk => { value += chunk })
  process.stdin.on('end', () => resolve(value))
  process.stdin.on('error', reject)
})
const requests = JSON.parse(source)
const results = requests.map(request => ({
  id: request.id,
  nodes: highlight(request.code, request.language),
}))
process.stdout.write(JSON.stringify(results))
