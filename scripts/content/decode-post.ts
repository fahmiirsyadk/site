import MarkdownIt from 'markdown-it'
import footnote from 'markdown-it-footnote'
import { Option, Schema as S } from 'effect'

import { parseMarkdown, type FrontmatterValue } from './frontmatter.ts'

export type Section = 'thought' | 'lab'

export type TocEntry = Readonly<{
  id: string
  label: string
  level: number
}>

export type Post = Readonly<{
  title: string
  date: string
  slug: string
  section: Section
  status: string
  tags: ReadonlyArray<string>
  excerpt: string | undefined
  banner: string | undefined
  ogTitle: string | undefined
  ogDescription: string | undefined
  ogImage: string | undefined
  html: string
  toc: ReadonlyArray<TocEntry>
}>

const markdown = new MarkdownIt({ html: true, linkify: true, typographer: true })
markdown.use(footnote)

const slugifyHeading = (value: string): string => {
  const slug = value
    .normalize('NFKD')
    .toLowerCase()
    .replace(/[^\p{Letter}\p{Number}]+/gu, '-')
    .replace(/^-+|-+$/gu, '')
  return slug.length > 0 ? slug : 'section'
}

type RenderedMarkdown = Readonly<{
  html: string
  toc: ReadonlyArray<TocEntry>
}>

const renderMarkdownWithToc = (source: string): RenderedMarkdown => {
  const environment = {}
  const tokens = markdown.parse(source, environment)
  const usedIds = new Map<string, number>()
  const toc: TocEntry[] = []

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index]
    if (token?.type !== 'heading_open') continue

    const level = Number(token.tag.slice(1))
    if (level < 2 || level > 4) continue

    const inline = tokens[index + 1]
    const label = inline?.type === 'inline' ? inline.content : ''
    const baseId = slugifyHeading(label)
    const occurrence = usedIds.get(baseId) ?? 0
    usedIds.set(baseId, occurrence + 1)
    const id = occurrence === 0 ? baseId : `${baseId}-${occurrence + 1}`

    token.attrSet('id', id)
    token.attrSet('tabindex', '-1')
    toc.push({ id, label, level })
  }

  return {
    html: markdown.renderer.render(tokens, markdown.options, environment),
    toc,
  }
}

const mediaPath = (source: string): string => source.split(/[?#]/, 1)[0]?.toLowerCase() ?? ''
const isGif = (source: string): boolean => mediaPath(source).endsWith('.gif')
const isMp4 = (source: string): boolean => mediaPath(source).endsWith('.mp4')

markdown.renderer.rules.image = (tokens, index) => {
  const token = tokens[index]
  const rawSource = token?.attrGet('src') ?? ''
  const noDitherMarker = '#no-dither'
  const noDither = rawSource.endsWith(noDitherMarker)
  const mediaSource = noDither ? rawSource.slice(0, -noDitherMarker.length) : rawSource
  const source = markdown.utils.escapeHtml(mediaSource)
  const alt = markdown.utils.escapeHtml(token?.content ?? '')
  const title = token?.attrGet('title')
  const titleAttribute =
    title === null || title === undefined ? '' : ` title="${markdown.utils.escapeHtml(title)}"`
  if (isMp4(mediaSource)) {
    return `<video class="markdown-video-plain" src="${source}" controls playsinline preload="metadata" aria-label="${alt}"${titleAttribute}></video>`
  }
  if (noDither || isGif(mediaSource)) {
    return `<img class="markdown-image-plain" src="${source}" alt="${alt}" loading="lazy"${titleAttribute}>`
  }
  return `<span class="dithered-image dithered-image-inline" data-dithered-image><img class="dithered-image-source" data-dithered-source src="${source}" alt="${alt}" loading="lazy"${titleAttribute}><canvas data-dithered-canvas aria-hidden="true"></canvas></span>`
}

export const renderMarkdown = (source: string): string => renderMarkdownWithToc(source).html

export const isSection = (value: string): value is Section =>
  value === 'thought' || value === 'lab'

const parseSection = (value: string | undefined): Section | undefined =>
  value !== undefined && isSection(value) ? value : undefined

const sectionOf = (path: string): Section => {
  const name = path.split('/').at(-2)
  return parseSection(name) ?? 'thought'
}

const maybeString = (value: FrontmatterValue | undefined): string | undefined =>
  Option.match(S.decodeUnknownOption(S.String)(value), {
    onNone: () => undefined,
    onSome: text => text,
  })

const maybeTags = (value: FrontmatterValue | undefined): ReadonlyArray<string> =>
  Option.match(S.decodeUnknownOption(S.Array(S.String))(value), {
    onNone: () => [],
    onSome: tags => tags,
  })

export const decodePost = (path: string, source: string): Post => {
  const parsed = parseMarkdown(source)
  const frontmatter = parsed.attributes
  const slug = maybeString(frontmatter.slug) ?? path.split('/').at(-1)?.replace(/\.md$/, '') ?? ''
  const section = parseSection(maybeString(frontmatter.section)) ?? sectionOf(path)

  const rendered = renderMarkdownWithToc(parsed.body)

  return {
    title: maybeString(frontmatter.title) ?? slug,
    date: maybeString(frontmatter.date) ?? '',
    slug,
    section,
    status: maybeString(frontmatter.status) ?? 'draft',
    tags: maybeTags(frontmatter.tags),
    excerpt: maybeString(frontmatter.excerpt),
    banner: maybeString(frontmatter.banner),
    ogTitle: maybeString(frontmatter.ogTitle),
    ogDescription: maybeString(frontmatter.ogDescription),
    ogImage: maybeString(frontmatter.ogImage),
    html: rendered.html,
    toc: rendered.toc,
  }
}
