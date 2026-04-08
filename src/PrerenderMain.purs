module PrerenderMain where

import Prelude

import App (renderStatic)
import Content (readSiteManifest)
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (Route, SiteManifest)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.String as String
import Effect (Effect)
import Effect.Console (log)
import Node.FS.Sync as FS
import Node.FS.Perms (permsAll)
import Node.Path (concat, dirname)
import Node.Process (cwd)
import Node.Encoding as Enc
import Data.Argonaut.Encode (encodeJson, toJsonString)
import Luna.Html as H
import Luna.Html.Document
  ( emptyDocument
  , renderDocument
  , withBodyHtml
  , withCharset
  , withInlineScript
  , withScriptDefer
  , withStylesheet
  , withTitle
  )
import Luna.Html.ModelState (serializeModelScript)

toOutputFile :: Route -> String
toOutputFile route =
  case printRoutePath route of
    "/" -> "index.html"
    path -> stripLeadingSlash path <> "/index.html"
  where
  stripLeadingSlash p = case String.take 1 p of
    "/" -> String.drop 1 p
    _ -> p

relativeAssetPath :: String -> String -> String
relativeAssetPath assetName outputFile =
  relativePrefix depth <> assetName
  where
  segments = String.split (String.Pattern "/") outputFile
  depth = max 0 (Array.length segments - 1)
  relativePrefix n = String.joinWith "" (Array.replicate n "../")

ensureDir :: String -> Effect Unit
ensureDir path =
  FS.mkdir' path { recursive: true, mode: permsAll }

renderPage :: String -> String -> SiteManifest -> Route -> String
renderPage title outputFile manifest route =
  renderDocument $
    emptyDocument
      # withTitle title
      # withCharset "UTF-8"
      # withStylesheet stylesheetHref
      # withBodyHtml bodyHtml
      # withInlineScript (serializeModelScript (toJsonString (encodeJson manifest)))
      # withScriptDefer scriptSrc
  where
  bodyHtml = void $ H.div [ H.id_ "app" ] [ renderStatic manifest route ]
  scriptSrc = relativeAssetPath "app.js" outputFile
  stylesheetHref = relativeAssetPath "css/style.css" outputFile

main :: Effect Unit
main = do
  projectRoot <- cwd
  let outDir = concat [ projectRoot, "dist" ]
  ensureDir outDir
  manifestResult <- readSiteManifest
  case manifestResult of
    Left err -> log $ "Error reading manifest: " <> err
    Right manifest -> do
      for_ (Pages.allRoutes manifest) \route -> do
        let outputFile = toOutputFile route
        let fullOutputFile = concat [ outDir, outputFile ]
        let parentDir = concat [ outDir, dirname outputFile ]
        ensureDir parentDir
        let title = Pages.titleFor manifest.posts route
        let doc = renderPage title outputFile manifest route
        FS.writeTextFile Enc.UTF8 fullOutputFile doc

      log "Prerendered site to dist/"