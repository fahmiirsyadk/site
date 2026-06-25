module Prerender.Config
  ( FontConfig
  , SiteMeta
  , defaultSiteMeta
  , fontConfig
  , HeadConfig
  , loadSiteMeta
  , mkHeadConfig
  , nonBlockingStylesheet
  , noscriptStylesheet
  , ogMeta
  , twitterMeta
  , preconnect
  , preloadFont
  , preloadScript
  , preloadStylesheet
  , absoluteUrl
  ) where

import Prelude

import Control.Alt ((<|>))
import Data.Argonaut.Core (toObject)
import Data.Argonaut.Decode (decodeJson)
import Data.Argonaut.Parser (jsonParser)
import Data.Either (Either(..), hush)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Effect (Effect)
import Effect.Exception (try)
import Foreign.Object as FO
import Node.Encoding as Enc
import Node.FS.Sync as FS
import Node.Process (lookupEnv)
import Luna.Html.Core (Html, attr, elem)

-- | Font asset URLs.
type FontConfig =
  { interRegular :: String
  , interMedium :: String
  , instrumentSerifLatin :: String
  }

fontConfig :: FontConfig
fontConfig =
  { interRegular: "https://rsms.me/inter/font-files/Inter-Regular.woff2?v=4.1"
  , interMedium: "https://rsms.me/inter/font-files/Inter-Medium.woff2?v=4.1"
  , instrumentSerifLatin: "https://fonts.gstatic.com/s/instrumentserif/v5/jizBRFtNs2ka5fXjeivQ4LroWlx-6zUTjg.woff2"
  }

-- | Site-wide metadata for social cards. `siteUrl` is the absolute origin
-- | (scheme + host, no trailing slash) used to build `og:url` / `og:image`
-- | absolute URLs. `SITE_URL` env var overrides the YAML value at build time.
type SiteMeta =
  { siteUrl :: String
  , siteName :: String
  , siteDescription :: String
  , defaultOgImage :: String
  , twitterHandle :: String
  , locale :: String
  }

defaultSiteMeta :: SiteMeta
defaultSiteMeta =
  { siteUrl: "https://fahmiirsyadk.com"
  , siteName: "Fahmi Irsyad Khairi"
  , siteDescription: "Notes on systems, software, and the long arc of building things that last."
  , defaultOgImage: "/assets/og/default.png"
  , twitterHandle: "@fahmiirsyadk"
  , locale: "en_US"
  }

-- | All config needed for `<head>` construction.
type HeadConfig =
  { buildHash :: String
  , fonts :: FontConfig
  , interStylesheet :: String
  , instrumentSerifStylesheet :: String
  , mainStylesheet :: String
  , scriptSrc :: String
  , site :: SiteMeta
  }

mkHeadConfig :: SiteMeta -> String -> HeadConfig
mkHeadConfig site buildHash =
  { buildHash
  , fonts: fontConfig
  , interStylesheet: "https://rsms.me/inter/inter.css"
  , instrumentSerifStylesheet: "https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap"
  , mainStylesheet: "/css/style.css"
  , scriptSrc: "/app.js"
  , site
  }

-- | Read site metadata from `site.json` at the project root. Falls back to
-- | `defaultSiteMeta` for any missing keys. The `SITE_URL` env var overrides
-- | the JSON `siteUrl` at build time (useful for staging / preview deploys).
loadSiteMeta :: Effect SiteMeta
loadSiteMeta = do
  jsonResult <- try (FS.readTextFile Enc.UTF8 "site.json")
  let
    jsonStr = case jsonResult of
      Left _ -> Nothing
      Right s -> case jsonParser s of
        Left _ -> Nothing
        Right j -> hush (decodeJson j)
    obj = jsonStr >>= toObject
    pick k = obj >>= FO.lookup k >>= decodeString
  envUrl <- lookupEnv "SITE_URL"
  let
    picked = defaultSiteMeta
      { siteUrl = fromMaybe defaultSiteMeta.siteUrl (envUrl <|> pick "siteUrl")
      , siteName = fromMaybe defaultSiteMeta.siteName (pick "siteName")
      , siteDescription = fromMaybe defaultSiteMeta.siteDescription (pick "siteDescription")
      , defaultOgImage = fromMaybe defaultSiteMeta.defaultOgImage (pick "defaultOgImage")
      , twitterHandle = fromMaybe defaultSiteMeta.twitterHandle (pick "twitterHandle")
      , locale = fromMaybe defaultSiteMeta.locale (pick "locale")
      }
  pure (normalizeSiteMeta picked)
  where
  decodeString j = hush (decodeJson j :: Either _ String)

-- | Strip trailing slash from siteUrl; safe defaults if empty.
normalizeSiteMeta :: SiteMeta -> SiteMeta
normalizeSiteMeta m =
  m { siteUrl = trimTrailingSlash m.siteUrl }

trimTrailingSlash :: String -> String
trimTrailingSlash s =
  let len = String.length s
  in if len > 0 && String.take 1 (String.drop (len - 1) s) == "/" then
       String.take (len - 1) s
     else s

-- | Combine origin + path into an absolute URL. Path can be absolute (starts with /)
-- | or relative — relative paths are appended to the origin; absolute paths get the
-- | origin prepended. Empty path yields just the origin.
absoluteUrl :: String -> String -> String
absoluteUrl origin path =
  let
    cleanPath = if String.length path > 0 && String.indexOf (String.Pattern "/") path == Just 0
      then path
      else "/" <> path
  in
    origin <> cleanPath

-- | `<meta property="og:..." content="..." />` (empty content is omitted).
ogMeta :: String -> String -> Html Unit
ogMeta k v =
  if String.length v == 0 then
    elem "meta" [] []
  else
    elem "meta"
      [ attr "property" k
      , attr "content" v
      ]
      []

-- | `<meta name="twitter:..." content="..." />` (empty content is omitted).
twitterMeta :: String -> String -> Html Unit
twitterMeta k v =
  if String.length v == 0 then
    elem "meta" [] []
  else
    elem "meta"
      [ attr "name" k
      , attr "content" v
      ]
      []

-- | `<link rel="preconnect" href="..." crossorigin="anonymous" />`
preconnect :: String -> Html Unit
preconnect href =
  elem "link"
    [ attr "rel" "preconnect"
    , attr "href" href
    , attr "crossorigin" "anonymous"
    ]
    []

-- | `<link rel="preload" href="..." as="font" type="font/woff2" crossorigin="anonymous" />`
preloadFont :: String -> Html Unit
preloadFont href =
  elem "link"
    [ attr "rel" "preload"
    , attr "href" href
    , attr "as" "font"
    , attr "type" "font/woff2"
    , attr "crossorigin" "anonymous"
    ]
    []

-- | `<link rel="preload" href="..." as="style" onload="this.onload=null;this.rel='stylesheet'" />`
nonBlockingStylesheet :: String -> Html Unit
nonBlockingStylesheet href =
  elem "link"
    [ attr "rel" "preload"
    , attr "href" href
    , attr "as" "style"
    , attr "onload" "this.onload=null;this.rel='stylesheet'"
    ]
    []

-- | `<noscript><link rel="stylesheet" href="..." /></noscript>`
noscriptStylesheet :: String -> Html Unit
noscriptStylesheet href =
  elem "noscript" []
    [ elem "link" [ attr "rel" "stylesheet", attr "href" href ] [] ]

-- | `<link rel="preload" href="..." as="style" />`
preloadStylesheet :: String -> Html Unit
preloadStylesheet href =
  elem "link" [ attr "rel" "preload", attr "as" "style", attr "href" href ] []

-- | `<link rel="preload" href="..." as="script" />`
preloadScript :: String -> Html Unit
preloadScript href =
  elem "link"
    [ attr "rel" "preload"
    , attr "href" href
    , attr "as" "script"
    ]
    []
