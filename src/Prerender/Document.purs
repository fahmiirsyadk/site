module Prerender.Document
  ( renderPage
  , toOutputFile
  ) where

import Prelude

import App (renderStatic, ssgBodyHtml)
import Data.Maybe (fromMaybe)
import Data.String as String
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
import Prerender.Config (HeadConfig, nonBlockingStylesheet, noscriptStylesheet, preconnect, preloadFont, preloadScript, preloadStylesheet)
import Prerender.Pages as Pages
import Routes (printRoutePath)
import Types (Route, SiteManifest)

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

themeBootScript :: String
themeBootScript =
  "(function(){var h=document.documentElement;try{var s=localStorage.getItem('theme');if(s==='dark'){h.classList.add('dark');h.style.colorScheme='dark'}else{h.classList.remove('dark');h.style.colorScheme='light'}}catch(e){try{h.classList.remove('dark');h.style.colorScheme='light'}catch(_){}}})();"
