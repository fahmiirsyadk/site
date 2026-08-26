type SourcePost = Readonly<{
  title: string
  date: string
  slug: string
  section: string
  status: string
  excerpt?: string
  banner?: string
  ogTitle?: string
  ogDescription?: string
  ogImage?: string
  html: string
  toc: ReadonlyArray<{
    id: string
    label: string
    level: number
  }>
}>

type RuntimePost = Readonly<{
  title: string
  date: string
  slug: string
  section: string
  status: string
  excerpt: string
  banner: string
  ogTitle: string
  ogDescription: string
  ogImage: string
  html: string
  toc: ReadonlyArray<{
    id: string
    label: string
    level: number
  }>
}>

const content: Readonly<Record<string, SourcePost>> =
  typeof import.meta.env === 'object'
    ?       import.meta.glob<SourcePost>('../content/*.md', {
        eager: true,
        query: '?site-content',
        import: 'default',
      })
    : {}

export const loadedPosts: ReadonlyArray<RuntimePost> = Object.values(content).map(post => ({
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
  toc: post.toc,
}))
