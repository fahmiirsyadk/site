import { fileURLToPath } from 'node:url'

import { defineConfig } from 'vitest/config'

import { siteContent } from './scripts/site-content-plugin.ts'

export default defineConfig({
  plugins: [siteContent()],
  resolve: {
    alias: {
      purescript: fileURLToPath(new URL('./output', import.meta.url)),
    },
  },
  test: {
    include: ['src/**/*.{test,spec}.ts'],
    environment: 'happy-dom',
    setupFiles: ['./src/vitest-setup.ts'],
    server: {
      deps: {
        inline: ['foldkit', '@foldkit/ui', '@foldkit/devtools'],
      },
    },
  },
})
