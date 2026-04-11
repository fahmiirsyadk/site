module PrerenderMain where

import Prelude

import App (renderStatic)
import Content (readSiteManifest)
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (BodyBlock, Post, Route(..), SiteManifest, Thought, TocItem)
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
import Luna.Html.Document
  ( emptyDocument
  , renderDocument
  , withBodyHtml
  , withCharset
  , withInlineScript
  , withMeta
  , withScriptDefer
  , withStylesheet
  , withTitle
  )
import Luna.Html.ModelState (serializeModelScript)

foreign import buildTimestamp :: Effect String

type PostContentPayload =
  { section :: String
  , slug :: String
  , bodyHtml :: String
  , bodyBlocks :: Array BodyBlock
  , toc :: Array TocItem
  }

stripThoughtBody :: Thought -> Thought
stripThoughtBody t = t { bodyHtml = "" }

-- | Drop heavy fields from the hydration payload. On `SectionPost`, keep `bodyBlocks` for the
-- | active article so SSR and client hydrate match (same Luna tree as `renderStatic`).
stripPost :: Post -> Post
stripPost p = p { bodyHtml = Nothing, bodyBlocks = [] }

slicePostForRoute :: String -> String -> Post -> Post
slicePostForRoute sec slug p =
  if p.section == sec && p.slug == slug then
    p { bodyHtml = Nothing }
  else
    stripPost p

sliceManifest :: Route -> SiteManifest -> SiteManifest
sliceManifest route manifest =
  case route of
    SectionPost sec slug ->
      manifest
        { posts = map (slicePostForRoute sec slug) manifest.posts
        , thoughts = map stripThoughtBody manifest.thoughts
        }
    _ ->
      manifest
        { posts = map stripPost manifest.posts
        , thoughts = map stripThoughtBody manifest.thoughts
        }

-- | Full index JSON: drop heavy fields; clients load bodies from per-post `/data/posts/.../*.json`.
manifestForSiteIndexJson :: SiteManifest -> SiteManifest
manifestForSiteIndexJson m =
  m { posts = map (\p -> p { bodyHtml = Nothing, bodyBlocks = [] }) m.posts }

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

renderPage :: String -> SiteManifest -> Route -> String -> String
renderPage buildHash manifest route slicedModelJson =
  renderDocument $
    emptyDocument
      # withTitle title
      # withCharset "UTF-8"
      # withMeta "viewport" "width=device-width, initial-scale=1"
      # withMeta "color-scheme" "light dark"
      # withStylesheet (stylesheetHref <> "?v=" <> buildHash)
      # withBodyHtml bodyHtml
      # withInlineScript themeBootScript
      # withInlineScript (serializeModelScript slicedModelJson)
      # withScriptDefer (scriptSrc <> "?v=" <> buildHash)
  where
  title = Pages.titleFor manifest.posts route
  sm = sliceManifest route manifest
  -- Same sliced manifest as `serializeModelScript` so SSR DOM and `__LUNA_INITIAL_MODEL__` match on hydrate.
  bodyHtml = void $ H.div [ H.id_ "app" ] [ renderStatic sm route ]
  scriptSrc = "/app.js"
  stylesheetHref = "/css/style.css"

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
        let doc = renderPage buildHash manifest route slicedJson
        FS.writeTextFile Enc.UTF8 fullOutputFile doc

      log "Prerendered site to dist/"