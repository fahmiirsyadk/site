module PrerenderMain where

import Prelude

import App (renderStatic)
import Content (readSiteManifest)
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (Post, Route(..), SiteManifest, Thought, TocItem)
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (fromMaybe)
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
  , withMeta
  , withScriptDefer
  , withStylesheet
  , withTitle
  )
import Luna.Html.ModelState (serializeModelScript)

type PostContentPayload =
  { section :: String
  , slug :: String
  , bodyHtml :: String
  , toc :: Array TocItem
  }

stripBodyHtml :: Post -> Post
stripBodyHtml p = p { bodyHtml = "" }

stripThoughtBody :: Thought -> Thought
stripThoughtBody t = t { bodyHtml = "" }

sliceManifest :: Route -> SiteManifest -> SiteManifest
sliceManifest route manifest =
  case route of
    Home -> manifest { posts = map stripBodyHtml manifest.posts, thoughts = map stripThoughtBody manifest.thoughts }
    About -> manifest { posts = map stripBodyHtml manifest.posts, thoughts = map stripThoughtBody manifest.thoughts }
    SectionIndex _ -> manifest { posts = map stripBodyHtml manifest.posts, thoughts = map stripThoughtBody manifest.thoughts }
    SectionPost section slug -> manifest { posts = map (keepIfCurrentPost section slug) manifest.posts, thoughts = map stripThoughtBody manifest.thoughts }
  where
  keepIfCurrentPost section slug post =
    if post.slug == slug && post.section == section then post else stripBodyHtml post

toOutputFile :: Route -> String
toOutputFile route =
  case printRoutePath route of
    "/" -> "index.html"
    path -> stripLeadingSlash path <> "/index.html"
  where
  stripLeadingSlash p = fromMaybe p (String.stripPrefix (String.Pattern "/") p)

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
        , bodyHtml: post.bodyHtml
        , toc: post.toc
        }
  FS.writeTextFile Enc.UTF8 (concat [ outDir, outputFile ]) (toJsonString (encodeJson payload))

renderPage :: SiteManifest -> Route -> String
renderPage manifest route =
  renderDocument $
    emptyDocument
      # withTitle title
      # withCharset "UTF-8"
      # withMeta "viewport" "width=device-width, initial-scale=1"
      # withStylesheet stylesheetHref
      # withBodyHtml bodyHtml
      # withInlineScript (serializeModelScript (toJsonString (encodeJson slicedManifest)))
      # withScriptDefer scriptSrc
  where
  title = Pages.titleFor manifest.posts route
  slicedManifest = sliceManifest route manifest
  bodyHtml = void $ H.div [ H.id_ "app" ] [ renderStatic manifest route ]
  scriptSrc = "/app.js"
  stylesheetHref = "/css/style.css"

main :: Effect Unit
main = do
  projectRoot <- cwd
  let outDir = concat [ projectRoot, "dist" ]
  ensureDir outDir
  manifestResult <- readSiteManifest
  case manifestResult of
    Left err -> log $ "Error reading manifest: " <> err
    Right manifest -> do
      FS.writeTextFile Enc.UTF8 (concat [ outDir, "site-manifest.json" ]) (toJsonString (encodeJson manifest))
      for_ manifest.posts (writePostPayload outDir)
      for_ (Pages.allRoutes manifest) \route -> do
        let outputFile = toOutputFile route
        let fullOutputFile = concat [ outDir, outputFile ]
        let outputDir = dirname outputFile
        when (outputDir /= ".") do
          ensureDir (concat [ outDir, outputDir ])
        let doc = renderPage manifest route
        FS.writeTextFile Enc.UTF8 fullOutputFile doc

      log "Prerendered site to dist/"