-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The HTML document around 'Site.View.viewModel'.
--
-- Only the native prerender generator uses this: it renders every route to a
-- complete file with 'Miso.Html.Render.toHtml'. The browser never reaches it,
-- so nothing here may touch the DOM.
--
-- The head is built from 'Site.Meta' rather than sitting in a static template.
-- One catalog therefore drives the title, the description, the social card,
-- the canonical URL, and the sitemap the generator writes alongside.
module Site.Document
  ( documentView
  , antiFlashScript
  ) where
-----------------------------------------------------------------------------
import           Miso (View, text)
import qualified Miso.Html.Element as H
import qualified Miso.Html.Property as P
import           Miso.Property (textProp)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.Action (Action)
import qualified Site.Config as Config
import           Site.Meta (Meta (..))
import qualified Site.Meta as Meta
import           Site.Model (Model)
import qualified Site.Model as Model
import           Site.Route (Route)
import           Site.Theme (Theme (..))
import qualified Site.Theme as Theme
import           Site.View (viewModel)
-----------------------------------------------------------------------------
-- | A complete document for one route: doctype, head, and the same body the
-- browser will hydrate.
--
-- The model is deliberately theme-independent ('Light'): the toggle renders
-- both icons and CSS selects one from the @dark@ class, so the markup is
-- stable no matter which theme the reader stored. The client adopts the real
-- theme after mounting, when the pre-paint script and the model can agree.
--
-- The version is a content hash of the deployed payload, appended to the
-- stylesheet and loader URLs as @?v=@. The loader propagates the same stamp
-- to the FFI glue and WASM, so one deploy always loads together.
documentView :: MisoString -> Route -> Meta -> [View () Model Action]
documentView version route meta =
  [ H.doctype_
  , H.html_
      [ P.lang_ "en" ]
      [ H.head_ [] (headNodes version route meta)
      , H.body_ [] [ viewModel () () (Model.modelFor route Light) ]
      ]
  ]
-----------------------------------------------------------------------------
headNodes :: MisoString -> Route -> Meta -> [View () Model Action]
headNodes version route meta =
  [ H.meta_ [ P.charset_ "utf-8" ]
  , H.meta_ [ P.name_ "viewport", P.content_ "width=device-width, initial-scale=1" ]
  , H.title_ [] [ text (metaTitle meta) ]
  , H.meta_ [ P.name_ "description", P.content_ (metaDescription meta) ]
    -- Open Graph
  , H.meta_ [ textProp "property" "og:site_name", P.content_ Config.siteName ]
  , H.meta_ [ textProp "property" "og:type", P.content_ (metaType meta) ]
  , H.meta_ [ textProp "property" "og:title", P.content_ (metaTitle meta) ]
  , H.meta_ [ textProp "property" "og:description", P.content_ (metaDescription meta) ]
  , H.meta_ [ textProp "property" "og:image", P.content_ (metaImage meta) ]
  , H.meta_ [ textProp "property" "og:url", P.content_ canonical ]
    -- Twitter
  , H.meta_ [ P.name_ "twitter:card", P.content_ "summary_large_image" ]
  , H.meta_ [ P.name_ "twitter:title", P.content_ (metaTitle meta) ]
  , H.meta_ [ P.name_ "twitter:description", P.content_ (metaDescription meta) ]
  , H.meta_ [ P.name_ "twitter:image", P.content_ (metaImage meta) ]
    -- Identity and fonts
  , H.link_ [ P.rel_ "canonical", P.href_ canonical ]
  , H.link_ [ P.rel_ "icon", P.type_ "image/svg+xml", P.href_ "/favicon.svg" ]
  , H.link_ [ P.rel_ "preload", P.href_ "/fonts/InterVariable.woff2"
            , textProp "as" "font", P.type_ "font/woff2", textProp "crossorigin" "" ]
  , H.link_ [ P.rel_ "preload", P.href_ "/fonts/InstrumentSerif-Regular.ttf"
            , textProp "as" "font", P.type_ "font/ttf", textProp "crossorigin" "" ]
  , H.link_ [ P.rel_ "preload", P.href_ "/fonts/InstrumentSerif-Italic.ttf"
            , textProp "as" "font", P.type_ "font/ttf", textProp "crossorigin" "" ]
  , H.link_ [ P.rel_ "stylesheet", P.href_ ("/styles.css" <> stamp version) ]
    -- Theme before first paint, then the WASM loader.
  , H.script_ [] antiFlashScript
  , H.script_ [ P.src_ ("/index.js" <> stamp version), P.type_ "module", P.defer_ True ] ""
  ]
  where
    canonical = Meta.canonicalForRoute route

stamp :: MisoString -> MisoString
stamp version = "?v=" <> version
-----------------------------------------------------------------------------
-- | Applies the stored or system theme before first paint. Built from the
-- same constants 'Site.Platform.applyTheme' uses -- the storage key, the
-- class, and the media query -- so the script cannot drift from the runtime.
-- The @js@ class gates the pre-dither placeholder in @styles/input.css@, so a
-- no-JS page keeps the plain image.
antiFlashScript :: MisoString
antiFlashScript =
  "(function(){"
  <> "document.documentElement.classList.add('js');"
  <> "var systemDark=false;"
  <> "try{systemDark=window.matchMedia('" <> Config.prefersDarkQuery <> "').matches;}catch(_){}"
  <> "var stored=null;"
  <> "try{stored=localStorage.getItem('" <> Config.themeStorageKey <> "');}catch(_){}"
  <> "var dark=stored==='" <> Theme.storageName Dark
  <> "'||(stored!=='" <> Theme.storageName Light <> "'&&systemDark);"
  <> "document.documentElement.classList.toggle('" <> Config.darkClassName <> "',dark);"
  <> "})()"
