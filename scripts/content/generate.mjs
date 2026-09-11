// Content generator: reads content/*.md, parses markdown and highlights code
// at build time, and emits generated/Site/Content/Generated.hs.
//
// The output is structured data (Site.Prose's Block/Inline AST), not HTML, so
// the browser and the native prerenderer render identical pages from pure
// Miso views. Run through `make content` before any cabal build.
import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

import hljs from 'highlight.js/lib/core'
import bash from 'highlight.js/lib/languages/bash'
import haskell from 'highlight.js/lib/languages/haskell'
import ini from 'highlight.js/lib/languages/ini'
import javascript from 'highlight.js/lib/languages/javascript'
import json from 'highlight.js/lib/languages/json'
import MarkdownIt from 'markdown-it'
import footnote from 'markdown-it-footnote'

hljs.registerLanguage('bash', bash)
hljs.registerLanguage('haskell', haskell)
hljs.registerLanguage('ini', ini)
hljs.registerLanguage('javascript', javascript)
hljs.registerLanguage('json', json)

// highlight.js has no PureScript grammar -- the Haskell grammar reads it well
// enough (same comments, strings, declarations, most keywords) -- and TOML is
// close enough to the INI grammar.
const LANGUAGE_ALIASES = { purescript: 'haskell', toml: 'ini' }

const CONTENT_DIR = 'content'
const OUTPUT_FILE = join('generated', 'Site', 'Content', 'Generated.hs')
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const markdown = new MarkdownIt({ html: true, linkify: true, typographer: true }).use(footnote)

// ---------------------------------------------------------------------------
// Frontmatter: the same line-based subset the old site parsed.
// ---------------------------------------------------------------------------

const parseFrontmatter = source => {
  const match = source.match(/^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/)
  if (match === null) return { attributes: {}, body: source }
  const attributes = {}
  for (const line of (match[1] ?? '').split('\n')) {
    const separator = line.indexOf(':')
    if (separator < 0) continue
    const key = line.slice(0, separator).trim()
    const raw = line.slice(separator + 1).trim()
    if (raw.startsWith('[')) {
      try { attributes[key] = JSON.parse(raw) } catch { attributes[key] = [] }
    } else {
      attributes[key] = raw.replace(/^"|"$/g, '')
    }
  }
  return { attributes, body: match[2] ?? '' }
}

// ---------------------------------------------------------------------------
// Token walk -> AST
// ---------------------------------------------------------------------------

const slugify = value => {
  const slug = value
    .normalize('NFKD')
    .toLowerCase()
    .replace(/[^\p{Letter}\p{Number}]+/gu, '-')
    .replace(/^-+|-+$/gu, '')
  return slug.length > 0 ? slug : 'section'
}

const dateLabel = value => {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value)
  if (match === null) return value
  const month = MONTHS[Number(match[2]) - 1] ?? match[2]
  return `${month} ${Number(match[3])}, ${match[1]}`
}

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

// highlight.js output is a tiny HTML subset: text plus nested classed spans.
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

const mediaPath = source => (source.split(/[?#]/, 1)[0] ?? '').toLowerCase()
const isGif = source => mediaPath(source).endsWith('.gif')
const isMp4 = source => mediaPath(source).endsWith('.mp4')

const parseImage = token => {
  const rawSource = token.attrGet('src') ?? ''
  const noDither = rawSource.endsWith('#no-dither')
  const source = noDither ? rawSource.slice(0, -'#no-dither'.length) : rawSource
  const alt = token.content ?? ''
  const title = token.attrGet('title')
  if (isMp4(source)) return { kind: 'video', source, alt, title }
  if (noDither || isGif(source)) return { kind: 'plainImage', source, alt, title }
  return { kind: 'image', source, alt, title }
}

// Inline tokens, recursing through open/close pairs.
const parseInlines = (children, state) => {
  let index = 0
  const parse = () => {
    const inlines = []
    while (index < children.length) {
      const token = children[index]
      if (token.nesting === -1) { index += 1; break }
      switch (token.type) {
        case 'text':
          inlines.push({ kind: 'text', value: token.content })
          index += 1
          break
        case 'code_inline':
          inlines.push({ kind: 'code', value: token.content })
          index += 1
          break
        case 'softbreak':
          inlines.push({ kind: 'softBreak' })
          index += 1
          break
        case 'hardbreak':
          inlines.push({ kind: 'hardBreak' })
          index += 1
          break
        case 'image':
          inlines.push(parseImage(token))
          index += 1
          break
        case 'footnote_ref': {
          const number = (token.meta?.id ?? 0) + 1
          const subId = token.meta?.subId ?? 0
          const refId = subId > 0 ? `fnref${number}:${subId}` : `fnref${number}`
          const refs = state.footnoteRefs.get(number) ?? []
          refs.push(refId)
          state.footnoteRefs.set(number, refs)
          inlines.push({ kind: 'footnoteRef', number, refId })
          index += 1
          break
        }
        case 'html_inline':
          throw new Error(`raw HTML inline is not supported by the structured renderer: ${token.content}`)
        case 'em_open':
          index += 1
          inlines.push({ kind: 'emphasis', children: parse() })
          break
        case 'strong_open':
          index += 1
          inlines.push({ kind: 'strong', children: parse() })
          break
        case 'link_open': {
          const href = token.attrGet('href') ?? ''
          const title = token.attrGet('title')
          index += 1
          inlines.push({ kind: 'link', href, title, children: parse() })
          break
        }
        default:
          throw new Error(`unhandled inline token: ${token.type}`)
      }
    }
    return inlines
  }
  return parse()
}

const matchClosers = tokens => {
  const stack = []
  const match = new Map()
  tokens.forEach((token, index) => {
    if (token.nesting === 1) stack.push(index)
    else if (token.nesting === -1) match.set(stack.pop(), index)
  })
  return match
}

const parseBlocks = (tokens, match, state, start, end) => {
  const blocks = []
  let index = start
  while (index < end) {
    const token = tokens[index]
    switch (token.type) {
      case 'paragraph_open': {
        const inline = tokens[index + 1]
        const inlines = parseInlines(inline.children ?? [], state)
        blocks.push(token.hidden ? { kind: 'plain', inlines } : { kind: 'paragraph', inlines })
        index = (match.get(index) ?? index) + 1
        break
      }
      case 'heading_open': {
        const level = Number(token.tag.slice(1))
        const inline = tokens[index + 1]
        let anchor = ''
        if (level >= 2 && level <= 4) {
          const base = slugify(inline.content ?? '')
          const seen = state.headingCounts.get(base) ?? 0
          state.headingCounts.set(base, seen + 1)
          anchor = seen === 0 ? base : `${base}-${seen + 1}`
          state.toc.push({ id: anchor, label: plainText(parseInlines(inline.children ?? [], state)), level })
        }
        blocks.push({ kind: 'heading', level, anchor, inlines: parseInlines(inline.children ?? [], state) })
        index = (match.get(index) ?? index) + 1
        break
      }
      case 'fence': {
        const language = (token.info ?? '').trim().split(/\s+/)[0] ?? ''
        blocks.push({ kind: 'codeBlock', language, inlines: highlight(token.content, language) })
        index += 1
        break
      }
      case 'code_block':
        blocks.push({ kind: 'codeBlock', language: '', inlines: highlight(token.content, '') })
        index += 1
        break
      case 'bullet_list_open':
      case 'ordered_list_open': {
        const close = match.get(index) ?? index
        const items = []
        let itemIndex = index + 1
        while (itemIndex < close) {
          const itemClose = match.get(itemIndex) ?? itemIndex
          items.push(parseBlocks(tokens, match, state, itemIndex + 1, itemClose))
          itemIndex = itemClose + 1
        }
        blocks.push({ kind: token.type === 'bullet_list_open' ? 'bulletList' : 'orderedList', items })
        index = close + 1
        break
      }
      case 'blockquote_open': {
        const close = match.get(index) ?? index
        blocks.push({ kind: 'blockQuote', blocks: parseBlocks(tokens, match, state, index + 1, close) })
        index = close + 1
        break
      }
      case 'table_open': {
        const close = match.get(index) ?? index
        const header = []
        const body = []
        let target = body
        let row = null
        for (let cursor = index + 1; cursor < close; cursor += 1) {
          const cell = tokens[cursor]
          if (cell.type === 'thead_open') target = header
          else if (cell.type === 'tbody_open') target = body
          else if (cell.type === 'tr_open') { row = []; target.push(row) }
          else if (cell.type === 'inline') row.push(parseInlines(cell.children ?? [], state))
        }
        blocks.push({ kind: 'table', header, body })
        index = close + 1
        break
      }
      case 'hr':
        blocks.push({ kind: 'rule' })
        index += 1
        break
      case 'footnote_block_open': {
        const close = match.get(index) ?? index
        const footnotes = []
        let footnoteIndex = index + 1
        while (footnoteIndex < close) {
          if (tokens[footnoteIndex].type === 'footnote_open') {
            const number = (tokens[footnoteIndex].meta?.id ?? footnotes.length) + 1
            const footnoteClose = match.get(footnoteIndex) ?? footnoteIndex
            const blocks = parseBlocks(tokens, match, state, footnoteIndex + 1, footnoteClose)
            const refs = state.footnoteRefs.get(number) ?? [`fnref${number}`]
            footnotes.push({ number, refs, blocks })
            footnoteIndex = footnoteClose + 1
          } else {
            footnoteIndex += 1
          }
        }
        blocks.push({ kind: 'footnotes', footnotes })
        index = close + 1
        break
      }
      case 'html_block':
        throw new Error(`raw HTML block is not supported by the structured renderer: ${token.content.slice(0, 40)}`)
      default:
        throw new Error(`unhandled block token: ${token.type}`)
    }
  }
  return blocks
}

const plainText = inlines => inlines.map(inline => {
  switch (inline.kind) {
    case 'text':
    case 'code':
      return inline.value
    case 'emphasis':
    case 'strong':
    case 'link':
    case 'span':
      return plainText(inline.children)
    default:
      return ''
  }
}).join('')

// ---------------------------------------------------------------------------
// Haskell emission
// ---------------------------------------------------------------------------

const escapeString = value => {
  let out = '"'
  for (const character of value) {
    const code = character.codePointAt(0)
    switch (character) {
      case '\\': out += '\\\\'; break
      case '"': out += '\\"'; break
      case '\n': out += '\\n'; break
      case '\r': out += '\\r'; break
      case '\t': out += '\\t'; break
      default:
        if (code < 0x20) out += `\\x${code.toString(16)}\\&`
        else out += character
    }
  }
  return out + '"'
}

const hsMaybe = value => (value === null || value === undefined || value === '')
  ? 'Nothing'
  : `Just ${escapeString(value)}`

const hsList = (items, render) => `[${items.map(render).join(', ')}]`

const emitInline = inline => {
  switch (inline.kind) {
    case 'text': return `Text ${escapeString(inline.value)}`
    case 'emphasis': return `Emphasis ${hsList(inline.children, emitInline)}`
    case 'strong': return `Strong ${hsList(inline.children, emitInline)}`
    case 'code': return `Code ${escapeString(inline.value)}`
    case 'link': return `Link ${escapeString(inline.href)} ${hsMaybe(inline.title)} ${hsList(inline.children, emitInline)}`
    case 'image': return `Image ${escapeString(inline.source)} ${escapeString(inline.alt)} ${hsMaybe(inline.title)}`
    case 'plainImage': return `PlainImage ${escapeString(inline.source)} ${escapeString(inline.alt)} ${hsMaybe(inline.title)}`
    case 'video': return `Video ${escapeString(inline.source)} ${escapeString(inline.alt)} ${hsMaybe(inline.title)}`
    case 'softBreak': return 'SoftBreak'
    case 'hardBreak': return 'HardBreak'
    case 'footnoteRef': return `FootnoteRef ${inline.number} ${escapeString(inline.refId)}`
    case 'span': return `Span ${escapeString(inline.className)} ${hsList(inline.children, emitInline)}`
    default: throw new Error(`unhandled inline: ${inline.kind}`)
  }
}

const emitBlock = block => {
  switch (block.kind) {
    case 'paragraph': return `Paragraph ${hsList(block.inlines, emitInline)}`
    case 'plain': return `Plain ${hsList(block.inlines, emitInline)}`
    case 'heading': return `Heading ${block.level} ${escapeString(block.anchor)} ${hsList(block.inlines, emitInline)}`
    case 'codeBlock': return `CodeBlock ${block.language === '' ? 'Nothing' : `(Just ${escapeString(block.language)})`} ${hsList(block.inlines, emitInline)}`
    case 'bulletList': return `BulletList ${hsList(block.items, item => hsList(item, emitBlock))}`
    case 'orderedList': return `OrderedList ${hsList(block.items, item => hsList(item, emitBlock))}`
    case 'blockQuote': return `BlockQuote ${hsList(block.blocks, emitBlock)}`
    case 'table':
      return `Table ${hsList(block.header, row => hsList(row, cell => hsList(cell, emitInline)))} ${hsList(block.body, row => hsList(row, cell => hsList(cell, emitInline)))}`
    case 'rule': return 'Rule'
    case 'footnotes':
      return `Footnotes ${hsList(block.footnotes, footnote =>
        `Footnote ${footnote.number} ${hsList(footnote.refs, escapeString)} ${hsList(footnote.blocks, emitBlock)}`)}`
    default: throw new Error(`unhandled block: ${block.kind}`)
  }
}

const emitToc = entry =>
  `TocEntry { tocId = ${escapeString(entry.id)}, tocLabel = ${escapeString(entry.label)}, tocLevel = ${entry.level} }`

const emitPost = (post, binding) => {
  const field = (name, value) => `    , ${name} = ${value}`
  return [
    `${binding} :: Post`,
    `${binding} =`,
    '  Post',
    '    { postTitle = ' + escapeString(post.title),
    field('postDate', escapeString(post.date)),
    field('postDateLabel', escapeString(dateLabel(post.date))),
    field('postSlug', escapeString(post.slug)),
    field('postSection', escapeString(post.section)),
    field('postStatus', escapeString(post.status)),
    field('postTags', hsList(post.tags, escapeString)),
    field('postExcerpt', escapeString(post.excerpt)),
    field('postBanner', escapeString(post.banner)),
    field('postOgTitle', escapeString(post.ogTitle)),
    field('postOgDescription', escapeString(post.ogDescription)),
    field('postOgImage', escapeString(post.ogImage)),
    `    , postBody = ${hsList(post.body, emitBlock)}`,
    `    , postToc = ${hsList(post.toc, emitToc)}`,
    '    }',
    '',
  ].join('\n')
}

const bindingName = slug =>
  slug.replace(/-([a-z0-9])/g, (_, character) => character.toUpperCase()).replace(/[^a-zA-Z0-9]/g, '') || 'post'

const generate = async () => {
  const names = (await readdir(CONTENT_DIR)).filter(name => name.endsWith('.md')).sort()
  const posts = []
  for (const name of names) {
    const source = await readFile(join(CONTENT_DIR, name), 'utf8')
    const { attributes, body } = parseFrontmatter(source)
    const tokens = markdown.parse(body, {})
    const state = { headingCounts: new Map(), toc: [], footnoteRefs: new Map() }
    const blocks = parseBlocks(tokens, matchClosers(tokens), state, 0, tokens.length)
    const fallbackSlug = name.replace(/\.md$/, '')
    posts.push({
      title: attributes.title ?? fallbackSlug,
      date: attributes.date ?? '',
      slug: attributes.slug ?? fallbackSlug,
      section: attributes.section ?? 'thought',
      status: attributes.status ?? 'draft',
      tags: Array.isArray(attributes.tags) ? attributes.tags : [],
      excerpt: attributes.excerpt ?? '',
      banner: attributes.banner ?? '',
      ogTitle: attributes.ogTitle ?? '',
      ogDescription: attributes.ogDescription ?? '',
      ogImage: attributes.ogImage ?? '',
      body: blocks,
      toc: state.toc,
    })
  }

  const bindings = posts.map((post, index) => `post${index}`)
  const header = [
    '-- This file is generated by scripts/content/generate.mjs.',
    '-- Do not edit by hand; run `make content` instead.',
    '{-# LANGUAGE OverloadedStrings #-}',
    'module Site.Content.Generated (posts) where',
    '',
    'import Site.Content.Types (Post (..), TocEntry (..))',
    'import Site.Prose (Block (..), Footnote (..), Inline (..))',
    '',
    'posts :: [Post]',
    'posts =',
    `  [ ${bindings.join(', ')} ]`,
    '',
  ].join('\n')
  const bodyText = posts
    .map((post, index) => emitPost(post, bindings[index]))
    .join('\n')
  await mkdir(join('generated', 'Site', 'Content'), { recursive: true })
  await writeFile(OUTPUT_FILE, `${header}${bodyText}`, 'utf8')
  console.log(`Generated ${OUTPUT_FILE} from ${posts.length} post(s).`)
}

generate().catch(error => {
  console.error(error.message)
  process.exitCode = 1
})
