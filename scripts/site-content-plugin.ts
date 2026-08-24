import type { Plugin } from 'vite'

import { decodePost } from './content/decode-post.ts'

export const siteContent = (): Plugin => ({
  name: 'site-content',
  enforce: 'pre',
  transform(source, id) {
    const queryIndex = id.indexOf('?')
    if (queryIndex < 0 || !new URLSearchParams(id.slice(queryIndex + 1)).has('site-content')) {
      return null
    }
    const path = id.slice(0, queryIndex)
    return `export default ${JSON.stringify(decodePost(path, source))}`
  },
})
