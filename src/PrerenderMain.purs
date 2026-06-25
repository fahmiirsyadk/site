module PrerenderMain where

import Prelude

import Content (readSiteManifest)
import Data.Argonaut.Encode (encodeJson, toJsonString)
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.String.CodeUnits as SCU
import Effect (Effect)
import Effect.Console (log)
import ManifestSlice (manifestForSiteIndexJson, sliceManifest)
import Node.Encoding as Enc
import Node.FS.Perms (permsAll)
import Node.FS.Sync as FS
import Node.Path (concat, dirname)
import Node.Process (cwd, exit', lookupEnv)
import Prerender.Config (SiteMeta, loadSiteMeta, mkHeadConfig)
import Prerender.Document (renderPage, toOutputFile)
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (Post, PostContentPayload, SiteManifest, sectionToString)

foreign import buildTimestamp :: Effect String

readInlineModelLimit :: Effect (Maybe Int)
readInlineModelLimit = do
  ev <- lookupEnv "LUNA_INLINE_MODEL_MAX_BYTES"
  pure case ev of
    Nothing -> Nothing
    Just "0" -> Nothing
    Just "" -> Nothing
    Just s -> Int.fromString s

ensureDir :: String -> Effect Unit
ensureDir path =
  FS.mkdir' path { recursive: true, mode: permsAll }

writePostPayload :: String -> Post -> Effect Unit
writePostPayload outDir post = do
  let outputFile = "data/posts/" <> sectionToString post.section <> "/" <> post.slug <> ".json"
      parentDir = dirname outputFile
  when (parentDir /= ".") do
    ensureDir (concat [ outDir, parentDir ])
  let payload :: PostContentPayload
      payload =
        { section: sectionToString post.section
        , slug: post.slug
        , bodyHtml: fromMaybe "" post.bodyHtml
        , bodyBlocks: post.bodyBlocks
        , toc: post.toc
        }
  FS.writeTextFile Enc.UTF8 (concat [ outDir, outputFile ]) (toJsonString (encodeJson payload))

writeSiteManifest :: String -> SiteManifest -> Effect Unit
writeSiteManifest outDir manifest =
  FS.writeTextFile Enc.UTF8
    (concat [ outDir, "site-manifest.json" ])
    (toJsonString (encodeJson (manifestForSiteIndexJson manifest)))

writeRoutePages :: String -> SiteMeta -> String -> Maybe Int -> SiteManifest -> Effect Unit
writeRoutePages buildHash site outDir mbInlineLimit manifest =
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
        outputDir = dirname outputFile
    when (outputDir /= ".") do
      ensureDir (concat [ outDir, outputDir ])
    let doc = renderPage (mkHeadConfig site buildHash) manifest route
    FS.writeTextFile Enc.UTF8 (concat [ outDir, outputFile ]) doc

main :: Effect Unit
main = do
  projectRoot <- cwd
  buildHash <- buildTimestamp
  site <- loadSiteMeta
  log $ "Site meta: " <> site.siteUrl
  let outDir = concat [ projectRoot, "dist" ]
  ensureDir outDir
  manifestResult <- readSiteManifest
  case manifestResult of
    Left err -> log $ "Error reading manifest: " <> err
    Right manifest -> do
      mbInlineLimit <- readInlineModelLimit
      writeSiteManifest outDir manifest
      for_ manifest.posts (writePostPayload outDir)
      writeRoutePages buildHash site outDir mbInlineLimit manifest
      log "Prerendered site to dist/"
