import { mkdir, readdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

import { defaultMetadata, metadataForPostValue, type Post } from '../output/Domain.Content/index.ts'

import { decodePost } from './content/decode-post.ts'

type Metadata = Readonly<{
  path: string
  title: string
  description: string
  image: string
  contentType: string
}>

const siteUrl = 'https://faah.me'
const escapeHtml = (value: string): string =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')

const escapeXml = escapeHtml

const replaceMeta = (html: string, attribute: 'name' | 'property', key: string, value: string): string => {
  const tag = `<meta ${attribute}="${key}" content="${escapeHtml(value)}" />`
  const pattern = new RegExp(`<meta\\b[^>]*${attribute}="${key}"[^>]*>`, 'i')
  return pattern.test(html) ? html.replace(pattern, tag) : html.replace('</head>', `    ${tag}\n  </head>`)
}

const renderMetadata = (template: string, metadata: Metadata): string => {
  const canonical = `${siteUrl}${metadata.path}`
  const canonicalTag = `<link rel="canonical" href="${canonical}" />`
  const withCanonical = /<link\b[^>]*rel="canonical"[^>]*>/i.test(template)
    ? template.replace(/<link\b[^>]*rel="canonical"[^>]*>/i, canonicalTag)
    : template.replace('</head>', `    ${canonicalTag}\n  </head>`)
  const tags: ReadonlyArray<readonly ['name' | 'property', string, string]> = [
    ['name', 'description', metadata.description],
    ['property', 'og:title', metadata.title],
    ['property', 'og:description', metadata.description],
    ['property', 'og:image', metadata.image],
    ['property', 'og:type', metadata.contentType],
    ['property', 'og:url', canonical],
    ['name', 'twitter:title', metadata.title],
    ['name', 'twitter:description', metadata.description],
    ['name', 'twitter:image', metadata.image],
  ]
  return tags.reduce(
    (html, [attribute, key, value]) => replaceMeta(html, attribute, key, value),
    withCanonical.replace(/<title>[^<]*<\/title>/i, `<title>${escapeHtml(metadata.title)}</title>`),
  )
}

const postMetadata = async (): Promise<ReadonlyArray<Metadata>> => {
  const names = await readdir('src/content')
  const records = await Promise.all(
    names.filter(name => name.endsWith('.md')).map(async name => {
      const post = decodePost(name, await readFile(join('src/content', name), 'utf8'))
      if (post.status !== 'published') return []
      const runtimePost: Post = {
        title: post.title,
        date: post.date,
        slug: post.slug,
        section: post.section,
        status: post.status,
        excerpt: post.excerpt ?? '',
        banner: post.banner ?? '',
        ogTitle: post.ogTitle ?? '',
        ogDescription: post.ogDescription ?? '',
        ogImage: post.ogImage ?? '',
        html: post.html,
        toc: [...post.toc],
      }
      const postMeta = metadataForPostValue(runtimePost)
      const metadata: Metadata = {
        path: `/${post.section}/${post.slug}/`,
        ...postMeta,
      }
      return [metadata]
    }),
  )
  return records.flat()
}

const template = await readFile('dist/index.html', 'utf8')
const pages: ReadonlyArray<Metadata> = [
  { path: '/', ...defaultMetadata },
  { path: '/thought/', ...defaultMetadata, title: 'thought - Faah' },
  { path: '/lab/', ...defaultMetadata, title: 'lab - Faah' },
  { path: '/ssh/', ...defaultMetadata, title: 'SSH - Faah' },
  ...await postMetadata(),
]

await Promise.all(pages.map(async metadata => {
  const directory = metadata.path === '/' ? 'dist' : join('dist', metadata.path)
  await mkdir(directory, { recursive: true })
  await writeFile(join(directory, 'index.html'), renderMetadata(template, metadata))
}))

const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${pages.map(page => `  <url><loc>${escapeXml(`${siteUrl}${page.path}`)}</loc></url>`).join('\n')}
</urlset>
`
await writeFile('dist/sitemap.xml', sitemap)
await writeFile('dist/robots.txt', `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`)

console.log(`Prerendered metadata for ${pages.length} route(s), plus sitemap.xml and robots.txt.`)
