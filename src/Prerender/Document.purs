module Prerender.Document
  ( renderPage
  , toOutputFile
  ) where

import Prelude

import App (renderStatic, ssgBodyHtml)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.String as String
import Luna.Html.Core (Html, attr, elem)
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
import ManifestSlice (sliceManifest)
import Prerender.Config
  ( HeadConfig
  , absoluteUrl
  , nonBlockingStylesheet
  , noscriptStylesheet
  , ogMeta
  , preconnect
  , preloadFont
  , preloadScript
  , preloadStylesheet
  , twitterMeta
  )
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (Route(..), SiteManifest, findPost, sectionFrom)

toOutputFile :: Route -> String
toOutputFile route =
  case printRoutePath route of
    "/" -> "index.html"
    path ->
      let bare = fromMaybe path (String.stripPrefix (String.Pattern "/") path)
      in bare <> "/index.html"

renderPage :: HeadConfig -> SiteManifest -> Route -> String
renderPage cfg manifest route =
  renderDocument $
    emptyDocument
      # withTitle title
      # withCharset "UTF-8"
      # withMeta "viewport" "width=device-width, initial-scale=1"
      # withMeta "color-scheme" "light dark"
      # withHeadExtra (ogAndTwitterTags cfg manifest route)
      # withHeadExtra (preloadScript gfxBootHref)
      # withHeadExtra (preconnect interPreconnect)
      # withHeadExtra (preconnect fontPreconnect)
      # withHeadExtra (preloadFont cfg.fonts.interRegular)
      # withHeadExtra (preloadFont cfg.fonts.interMedium)
      # withHeadExtra (preloadFont cfg.fonts.instrumentSerifLatin)
      # withHeadExtra (nonBlockingStylesheet cfg.interStylesheet)
      # withHeadExtra (noscriptStylesheet cfg.interStylesheet)
      # withHeadExtra (nonBlockingStylesheet cfg.instrumentSerifStylesheet)
      # withHeadExtra (noscriptStylesheet cfg.instrumentSerifStylesheet)
      # withHeadExtra (preloadStylesheet styleHref)
      # withStylesheet styleHref
      # withBodyHtml bodyHtml
      # withInlineScript themeBootScript
      # withInlineScript (serializeModelScriptFrom (sliceManifest route) manifest)
      # withScriptDefer (cfg.scriptSrc <> "?v=" <> cfg.buildHash)
  where
  title = Pages.titleFor manifest.posts route
  sm = sliceManifest route manifest
  bodyHtml = void $ ssgBodyHtml cfg.buildHash (renderStatic sm route)
  styleHref = cfg.mainStylesheet <> "?v=" <> cfg.buildHash
  gfxBootHref = "/gfx-boot.js?v=" <> cfg.buildHash
  fontPreconnect = "https://fonts.gstatic.com"
  interPreconnect = "https://rsms.me"

-- | Open Graph + Twitter Card + article meta tags. Per-post values come from
-- | `Post.ogTitle` / `Post.ogDescription` / `Post.ogImage` (with fallbacks to
-- | title / description / banner). Non-post routes use site-level defaults.
ogAndTwitterTags :: HeadConfig -> SiteManifest -> Route -> Html Unit
ogAndTwitterTags cfg manifest route =
  let
    site = cfg.site
    routePath = printRoutePath route
    pageUrl = absoluteUrl site.siteUrl routePath
    currentPost = case route of
      SectionPost section slug -> findPost manifest.posts (sectionFrom section) slug
      _ -> Nothing
    ogTitleVal = case currentPost of
      Just p -> p.ogTitle
      Nothing ->
        case route of
          About -> "About — " <> site.siteName
          Home -> site.siteName
          SectionIndex "articles" -> "Articles — " <> site.siteName
          SectionIndex "projects" -> "Projects — " <> site.siteName
          SectionIndex "til" -> "TIL — " <> site.siteName
          SectionIndex s -> s <> " — " <> site.siteName
          _ -> site.siteName
    ogDescriptionVal = case currentPost of
      Just p -> p.ogDescription
      Nothing -> site.siteDescription
    ogImageRel = case currentPost of
      Just p -> p.ogImage
      Nothing -> site.defaultOgImage
    ogImageAbs = absoluteUrl site.siteUrl ogImageRel
    ogType = case currentPost of
      Just _ -> "article"
      Nothing -> "website"
    twitterCard = if String.length ogImageRel > 0 then "summary_large_image" else "summary"
    articleAuthor = case currentPost of
      Just _ -> Just site.siteName
      Nothing -> Nothing
    articlePublishedTime = case currentPost of
      Just p -> Just p.date
      Nothing -> Nothing
    articleTags = case currentPost of
      Just p -> p.tags
      Nothing -> []
    canonicalLink =
      elem "link"
        [ attr "rel" "canonical"
        , attr "href" pageUrl
        ]
        []
  in
    elem "div"
      [ attr "data-prerender-og" "1" ]
      ([ canonicalLink
       , ogMeta "og:title" ogTitleVal
       , ogMeta "og:description" ogDescriptionVal
       , ogMeta "og:type" ogType
       , ogMeta "og:url" pageUrl
       , ogMeta "og:site_name" site.siteName
       , ogMeta "og:locale" site.locale
       , ogMeta "og:image" ogImageAbs
       , ogMeta "og:image:width" "1200"
       , ogMeta "og:image:height" "630"
       , ogMeta "og:image:alt" ogTitleVal
       , twitterMeta "twitter:card" twitterCard
       , twitterMeta "twitter:site" site.twitterHandle
       , twitterMeta "twitter:creator" site.twitterHandle
       , twitterMeta "twitter:title" ogTitleVal
       , twitterMeta "twitter:description" ogDescriptionVal
       , twitterMeta "twitter:image" ogImageAbs
       , twitterMeta "twitter:image:alt" ogTitleVal
       ]
        <> maybe [] (\a -> [ogMeta "article:author" a]) articleAuthor
        <> maybe [] (\t -> [ogMeta "article:published_time" t]) articlePublishedTime
        <> map (\t -> ogMeta "article:tag" t) articleTags
      )

themeBootScript :: String
themeBootScript =
  "(function(){var h=document.documentElement;try{var s=localStorage.getItem('theme');if(s==='dark'){h.classList.add('dark');h.style.colorScheme='dark'}else{h.classList.remove('dark');h.style.colorScheme='light'}}catch(e){try{h.classList.remove('dark');h.style.colorScheme='light'}}catch(_){}}})();"
