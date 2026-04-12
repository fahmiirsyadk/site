module PrerenderMain where

import Prelude

import App (renderStatic)
import Content (readSiteManifest)
import ManifestSlice (manifestForSiteIndexJson, sliceManifest)
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (BodyBlock, Post, Route, SiteManifest, TocItem)
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.String as String
import Data.String.CodeUnits as SCU
import Effect (Effect)
import Effect.Console (log)
import Node.FS.Sync as FS
import Node.FS.Perms (permsAll)
import Node.Path (concat, dirname)
import Node.Process (cwd, exit', lookupEnv)
import Node.Encoding as Enc
import Data.Argonaut.Encode (encodeJson, toJsonString)
import Luna.Html as H
import Luna.Html.Core as HC
import Luna.Html.Document
  ( emptyDocument
  , renderDocument
  , withBodyHtml
  , withCharset
  , withHeadExtra
  , withInlineScript
  , withMeta
  , withScriptDefer
  , withStylesheet
  , withTitle
  )
import Luna.Html.ModelState (serializeModelScriptFrom)

foreign import buildTimestamp :: Effect String

type PostContentPayload =
  { section :: String
  , slug :: String
  , bodyHtml :: String
  , bodyBlocks :: Array BodyBlock
  , toc :: Array TocItem
  }

-- | When set, `LUNA_INLINE_MODEL_MAX_BYTES` caps UTF-16 code units per inlined model (ASCII-heavy JSON ≈ bytes). Unset or `0` = no check (CI can set e.g. `50000`).
readInlineModelLimit :: Effect (Maybe Int)
readInlineModelLimit = do
  ev <- lookupEnv "LUNA_INLINE_MODEL_MAX_BYTES"
  pure case ev of
    Nothing -> Nothing
    Just "0" -> Nothing
    Just "" -> Nothing
    Just s -> Int.fromString s

-- | Early `<html class="dark">` / `color-scheme` from `localStorage` + `prefers-color-scheme`.
themeBootScript :: String
themeBootScript =
  "(function(){var h=document.documentElement;function p(){try{return window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches}catch(e){return false}}try{var s=localStorage.getItem('theme');if(s==='dark'){h.classList.add('dark');h.style.colorScheme='dark'}else if(s==='light'){h.classList.remove('dark');h.style.colorScheme='light'}else{var d=p();h.classList.toggle('dark',d);h.style.colorScheme=d?'dark':'light'}}catch(e){var d2=p();h.classList.toggle('dark',d2);try{h.style.colorScheme=d2?'dark':'light'}catch(_){}}})();"

toOutputFile :: Route -> String
toOutputFile route =
  case printRoutePath route of
    "/" -> "index.html"
    path ->
      let bare = fromMaybe path (String.stripPrefix (String.Pattern "/") path)
      in bare <> "/index.html"

ensureDir :: String -> Effect Unit
ensureDir path =
  FS.mkdir' path { recursive: true, mode: permsAll }

postContentOutputFile :: Post -> String
postContentOutputFile post = "data/posts/" <> post.section <> "/" <> post.slug <> ".json"

writePostPayload :: String -> Post -> Effect Unit
writePostPayload outDir post = do
  let outputFile = postContentOutputFile post
  let parentDir = dirname outputFile
  when (parentDir /= ".") do
    ensureDir (concat [ outDir, parentDir ])
  let payload :: PostContentPayload
      payload =
        { section: post.section
        , slug: post.slug
        , bodyHtml: fromMaybe "" post.bodyHtml
        , bodyBlocks: post.bodyBlocks
        , toc: post.toc
        }
  FS.writeTextFile Enc.UTF8 (concat [ outDir, outputFile ]) (toJsonString (encodeJson payload))

renderPage :: String -> SiteManifest -> Route -> String
renderPage buildHash manifest route =
  renderDocument $
    emptyDocument
      # withTitle title
      # withCharset "UTF-8"
      # withMeta "viewport" "width=device-width, initial-scale=1"
      # withMeta "color-scheme" "light dark"
      -- Only 2 preconnects (Lighthouse: ≤4). Drop duplicate `Link: preconnect` from CDN if Lighthouse still doubles rsms.
      # withHeadExtra preconnectFontsGstatic
      # withHeadExtra preconnectInter
      -- Start woff2 fetches before font CSS applies (after async CSS below).
      # withHeadExtra (preloadFontWoff2 interRegularWoff2)
      # withHeadExtra (preloadFontWoff2 interMediumWoff2)
      # withHeadExtra (preloadFontWoff2 instrumentSerifLatinNormalWoff2)
      -- Third-party font CSS: preload → stylesheet on load (not render-blocking; web.dev/defer-non-critical-css).
      # withHeadExtra (nonBlockingStylesheet interStylesheetHref)
      # withHeadExtra (noscriptStylesheet interStylesheetHref)
      # withHeadExtra (nonBlockingStylesheet instrumentSerifStylesheetHref)
      # withHeadExtra (noscriptStylesheet instrumentSerifStylesheetHref)
      -- Main Tailwind bundle: preload + stylesheet share one URL (browser dedupes).
      # withHeadExtra (preloadStylesheet styleHref)
      # withStylesheet styleHref
      # withBodyHtml bodyHtml
      # withInlineScript themeBootScript
      # withInlineScript (serializeModelScriptFrom (sliceManifest route) manifest)
      # withScriptDefer (scriptSrc <> "?v=" <> buildHash)
  where
  title = Pages.titleFor manifest.posts route
  sm = sliceManifest route manifest
  -- Same sliced manifest as `serializeModelScript` so SSR DOM and `__LUNA_INITIAL_MODEL__` match on hydrate.
  bodyHtml = void $ H.div [ H.id_ "app" ] [ renderStatic sm route ]
  scriptSrc = "/app.js"
  stylesheetHref = "/css/style.css"
  styleHref = stylesheetHref <> "?v=" <> buildHash
  -- Must match `inter.css` from rsms.me (see `curl https://rsms.me/inter/inter.css`).
  interRegularWoff2 = "https://rsms.me/inter/font-files/Inter-Regular.woff2?v=4.1"
  interMediumWoff2 = "https://rsms.me/inter/font-files/Inter-Medium.woff2?v=4.1"
  -- Latin normal 400; from Google CSS `family=Instrument+Serif:ital@0;1&display=swap`. Update if Google changes paths.
  instrumentSerifLatinNormalWoff2 =
    "https://fonts.gstatic.com/s/instrumentserif/v5/jizBRFtNs2ka5fXjeivQ4LroWlx-6zUTjg.woff2"
  preconnectFontsGstatic =
    HC.elem "link"
      [ HC.attr "rel" "preconnect"
      , HC.attr "href" "https://fonts.gstatic.com"
      , HC.attr "crossorigin" "anonymous"
      ]
      []
  preconnectInter =
    HC.elem "link" [ HC.attr "rel" "preconnect", HC.attr "href" "https://rsms.me" ] []
  interStylesheetHref = "https://rsms.me/inter/inter.css"
  instrumentSerifStylesheetHref =
    "https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap"
  nonBlockingStylesheet href =
    HC.elem "link"
      [ HC.attr "rel" "preload"
      , HC.attr "href" href
      , HC.attr "as" "style"
      , HC.attr "onload" "this.onload=null;this.rel='stylesheet'"
      ]
      []
  noscriptStylesheet href =
    HC.elem "noscript" []
      [ HC.elem "link" [ HC.attr "rel" "stylesheet", HC.attr "href" href ] [] ]
  preloadStylesheet href =
    HC.elem "link" [ HC.attr "rel" "preload", HC.attr "as" "style", HC.attr "href" href ] []
  preloadFontWoff2 href =
    HC.elem "link"
      [ HC.attr "rel" "preload"
      , HC.attr "href" href
      , HC.attr "as" "font"
      , HC.attr "type" "font/woff2"
      , HC.attr "crossorigin" "anonymous"
      ]
      []

main :: Effect Unit
main = do
  projectRoot <- cwd
  buildHash <- buildTimestamp
  let outDir = concat [ projectRoot, "dist" ]
  ensureDir outDir
  manifestResult <- readSiteManifest
  case manifestResult of
    Left err -> log $ "Error reading manifest: " <> err
    Right manifest -> do
      mbInlineLimit <- readInlineModelLimit
      FS.writeTextFile Enc.UTF8 (concat [ outDir, "site-manifest.json" ])
        (toJsonString (encodeJson (manifestForSiteIndexJson manifest)))
      for_ manifest.posts (writePostPayload outDir)
      for_ (Pages.allRoutes manifest) \route -> do
        let slicedManifest = sliceManifest route manifest
            slicedJson = toJsonString (encodeJson slicedManifest)
            routeLabel = printRoutePath route
            n = SCU.length slicedJson
        log $ routeLabel <> ": __LUNA_INITIAL_MODEL__ JSON " <> show n <> " code units (ASCII-heavy JSON ≈ bytes)"
        flip (maybe (pure unit)) mbInlineLimit \lim ->
          when (n > lim) do
            log $ "Prerender failed: inline model exceeds LUNA_INLINE_MODEL_MAX_BYTES (" <> show lim <> ") for " <> routeLabel
            void (exit' 1)
        let outputFile = toOutputFile route
        let fullOutputFile = concat [ outDir, outputFile ]
        let outputDir = dirname outputFile
        when (outputDir /= ".") do
          ensureDir (concat [ outDir, outputDir ])
        let doc = renderPage buildHash manifest route
        FS.writeTextFile Enc.UTF8 fullOutputFile doc

      log "Prerendered site to dist/"