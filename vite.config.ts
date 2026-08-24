import { fileURLToPath } from 'node:url'

import { defineConfig } from 'vite'

import { foldkit } from '@foldkit/vite-plugin'
import tailwindcss from '@tailwindcss/vite'

import { pureScript } from './scripts/purescript-vite.js'
import { siteContent } from './scripts/site-content-plugin.ts'

export default defineConfig({
  plugins: [
    siteContent(),
    pureScript(),
    tailwindcss(),
    foldkit({
      devToolsMcpPort: 9988,
    }),
  ],
  resolve: {
    alias: {
      purescript: fileURLToPath(new URL('./output', import.meta.url)),
    },
  },
  optimizeDeps: {
    entries: ['src/entry.ts'],
  },
})
