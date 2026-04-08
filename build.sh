#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "Generating content from markdown..."
node scripts/build-content.js

echo "Compiling PureScript..."
pnpm exec spago build

echo "Running static site generator..."
pnpm exec spago run -p site --main PrerenderMain

echo "Bundling client JavaScript (purs-backend-es + esbuild minify)..."
mkdir -p dist
pnpm exec purs-backend-es build --int-tags
pnpm exec purs-backend-es bundle-app -m Main -p browser --minify --no-build -t dist/app.js

echo "Building CSS..."
mkdir -p dist/css
BROWSERSLIST_IGNORE_OLD_DATA=1 npx --yes tailwindcss@3.4.17 -c tailwind.config.cjs -i ./css/style.css -o ./dist/css/style.css --minify

echo "Copying static assets..."
mkdir -p dist/assets
mkdir -p dist/fonts
cp -r public/assets/* dist/assets/ 2>/dev/null || true
cp -r public/fonts/* dist/fonts/ 2>/dev/null || true

echo "Done. Output: dist/"