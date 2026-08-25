import { fileURLToPath } from 'node:url'

import { defineConfig } from 'vite'

import { foldkit } from '@foldkit/vite-plugin'
import tailwindcss from '@tailwindcss/vite'

import { siteContent } from './scripts/site-content-plugin.ts'

export default defineConfig({
  plugins: [
    siteContent(),
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
    entries: ['output/entry.ts'],
  },
})
