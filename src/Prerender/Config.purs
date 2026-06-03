module Prerender.Config
  ( FontConfig
  , fontConfig
  , HeadConfig
  , mkHeadConfig
  , nonBlockingStylesheet
  , noscriptStylesheet
  , preconnect
  , preloadFont
  , preloadScript
  , preloadStylesheet
  ) where

import Prelude

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

-- | All config needed for `<head>` construction.
type HeadConfig =
  { buildHash :: String
  , fonts :: FontConfig
  , interStylesheet :: String
  , instrumentSerifStylesheet :: String
  , mainStylesheet :: String
  , scriptSrc :: String
  }

mkHeadConfig :: String -> HeadConfig
mkHeadConfig buildHash =
  { buildHash
  , fonts: fontConfig
  , interStylesheet: "https://rsms.me/inter/inter.css"
  , instrumentSerifStylesheet: "https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap"
  , mainStylesheet: "/css/style.css"
  , scriptSrc: "/app.js"
  }

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
