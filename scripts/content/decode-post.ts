import MarkdownIt from 'markdown-it'
import footnote from 'markdown-it-footnote'

import { parseMarkdown } from './frontmatter.ts'

export type Section = 'thought' | 'lab'

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
}>

const markdown = new MarkdownIt({ html: true, linkify: true, typographer: true })
markdown.use(footnote)

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

export const renderMarkdown = (source: string): string => markdown.render(source)

export const isSection = (value: string): value is Section =>
  value === 'thought' || value === 'lab'

const parseSection = (value: string | undefined): Section | undefined =>
  value !== undefined && isSection(value) ? value : undefined

const sectionOf = (path: string): Section => {
  const name = path.split('/').at(-2)
  return parseSection(name) ?? 'thought'
}

const maybeString = (value: unknown): string | undefined =>
  typeof value === 'string' ? value : undefined

export const decodePost = (path: string, source: string): Post => {
  const parsed = parseMarkdown(source)
  const frontmatter = parsed.attributes
  const slug = maybeString(frontmatter.slug) ?? path.split('/').at(-1)?.replace(/\.md$/, '') ?? ''
  const section = parseSection(maybeString(frontmatter.section)) ?? sectionOf(path)

  return {
    title: maybeString(frontmatter.title) ?? slug,
    date: maybeString(frontmatter.date) ?? '',
    slug,
    section,
    status: maybeString(frontmatter.status) ?? 'draft',
    tags: Array.isArray(frontmatter.tags)
      ? frontmatter.tags.filter((tag: unknown): tag is string => typeof tag === 'string')
      : [],
    excerpt: maybeString(frontmatter.excerpt),
    banner: maybeString(frontmatter.banner),
    ogTitle: maybeString(frontmatter.ogTitle),
    ogDescription: maybeString(frontmatter.ogDescription),
    ogImage: maybeString(frontmatter.ogImage),
    html: renderMarkdown(parsed.body),
  }
}
