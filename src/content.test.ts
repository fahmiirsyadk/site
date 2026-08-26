import { describe, expect, test } from 'vitest'

import { posts } from 'purescript/Content.Repository/index.ts'
import { metadataForPath } from 'purescript/Domain.Content/index.ts'

import { decodePost, renderMarkdown } from '../scripts/content/decode-post.ts'

const render = (source: string): HTMLElement => {
  const root = document.createElement('div')
  root.innerHTML = renderMarkdown(source)
  return root
}

describe('Markdown images', () => {
  test('dithers images by default', () => {
    const root = render('![Diagram](/images/diagram.png)')

    expect(root.querySelector('[data-dithered-image]')).not.toBeNull()
    expect(root.querySelector('img[data-dithered-source]')?.getAttribute('src')).toBe(
      '/images/diagram.png',
    )
    expect(root.querySelector('canvas[data-dithered-canvas]')).not.toBeNull()
  })

  test('renders no-dither images without the WebGL wrapper', () => {
    const root = render('![Quarterly report](/images/report.png#no-dither "Report table")')
    const image = root.querySelector('img.markdown-image-plain')

    expect(root.querySelector('[data-dithered-image]')).toBeNull()
    expect(image?.getAttribute('src')).toBe('/images/report.png')
    expect(image?.getAttribute('alt')).toBe('Quarterly report')
    expect(image?.getAttribute('title')).toBe('Report table')
  })

  test('preserves ordinary image fragments', () => {
    const root = render('![Diagram](/images/diagram.svg#overview)')

    expect(root.querySelector('img[data-dithered-source]')?.getAttribute('src')).toBe(
      '/images/diagram.svg#overview',
    )
  })

  test('renders animated GIFs as native images', () => {
    const root = render('![Animation](/images/animation.gif)')

    expect(root.querySelector('img.markdown-image-plain')?.getAttribute('src')).toBe(
      '/images/animation.gif',
    )
    expect(root.querySelector('[data-dithered-image]')).toBeNull()
  })

  test('renders MP4 files as native videos', () => {
    const root = render('![Demo](/videos/demo.mp4 "Demo video")')
    const video = root.querySelector('video.markdown-video-plain')

    expect(video?.getAttribute('src')).toBe('/videos/demo.mp4')
    expect(video?.hasAttribute('controls')).toBe(true)
    expect(video?.getAttribute('title')).toBe('Demo video')
    expect(root.querySelector('[data-dithered-image]')).toBeNull()
  })
})

describe('Markdown headings', () => {
  test('adds stable heading ids and collects table-of-contents entries', () => {
    const root = render('# Title\n\n## How it started\n\n### Details\n\n## How it started')

    expect(root.querySelector('h1')?.hasAttribute('id')).toBe(false)
    expect(root.querySelector('h2')?.getAttribute('id')).toBe('how-it-started')
    expect(root.querySelectorAll('h2')[1]?.getAttribute('id')).toBe('how-it-started-2')
    expect(root.querySelector('h3')?.getAttribute('id')).toBe('details')
    expect(root.querySelector('h2')?.getAttribute('tabindex')).toBe('-1')
  })

  test('decodePost reports the collected table of contents', () => {
    const post = decodePost(
      'thought/how-it-started.md',
      '---\ntitle: How it started\n---\n\n## How it started\n\n### Details',
    )

    expect(post.toc).toEqual([
      { id: 'how-it-started', label: 'How it started', level: 2 },
      { id: 'details', label: 'Details', level: 3 },
    ])
  })
})

describe('Content publication and metadata', () => {
  test('excludes draft posts from the production repository', () => {
    expect(posts.some(post => post.slug === 'everyone-is-narcissistic-today')).toBe(false)
  })

  test('uses post Open Graph metadata for canonical post paths', () => {
    expect(metadataForPath(posts, '/thought/chaotic-pendulum/')).toMatchObject({
      contentType: 'article',
      image: 'https://faah.me/assets/banners/pendulum.png',
    })
  })
})
