{-# LANGUAGE OverloadedStrings #-}
module Site.Head (renderHead) where

import Lucid
import Data.Text (Text)
import Site.Theme (mk, rawHtml, themeBootScript, relativeTimeScript)
import Site.Types (HeadInfo(..))

siteName, siteUrl, siteDescription, defaultOgImage, twitterHandle, locale :: Text
siteName       = "Faah"
siteUrl        = "https://faah.me"
siteDescription = "Notes on systems, software, and the long arc of building things that last."
defaultOgImage = "/assets/og/default.png"
twitterHandle  = "@fahmiirsyadk"
locale         = "en_US"

ogMeta :: Text -> Text -> Html ()
ogMeta prop val = meta_ [mk "property" prop, mk "content" val]

twMeta :: Text -> Text -> Html ()
twMeta prop val = meta_ [mk "name" prop, mk "content" val]

ogBlock :: HeadInfo -> Html ()
ogBlock hi = do
  let base = [ link_ [rel_ "canonical", href_ (siteUrl <> hiPath hi)]
             , ogMeta "og:title" (hiTitle hi)
             , ogMeta "og:description" (hiDescription hi)
             , ogMeta "og:type" (hiOgType hi)
             , ogMeta "og:url" (siteUrl <> hiPath hi)
             , ogMeta "og:site_name" siteName
             , ogMeta "og:locale" locale
             , ogMeta "og:image" (siteUrl <> hiOgImage hi)
             , ogMeta "og:image:width" "1200"
             , ogMeta "og:image:height" "630"
             , ogMeta "og:image:alt" (hiTitle hi)
             , twMeta "twitter:card" "summary_large_image"
             , twMeta "twitter:site" twitterHandle
             , twMeta "twitter:creator" twitterHandle
             , twMeta "twitter:title" (hiTitle hi)
             , twMeta "twitter:description" (hiDescription hi)
             , twMeta "twitter:image" (siteUrl <> hiOgImage hi)
             , twMeta "twitter:image:alt" (hiTitle hi)
             ]
      articleExtras = [ ogMeta "article:author" siteName
                      , ogMeta "article:published_time" (hiPublished hi)
                      ]
      tagExtras = map (\t -> ogMeta "article:tag" t) (hiTags hi)
  div_ [mk "data-prerender-og" "1"] (sequence_ (base ++ (if hiOgType hi == "article" then articleExtras else []) ++ tagExtras))

renderHead :: HeadInfo -> Html ()
renderHead hi = head_ $ do
  title_ (toHtml (hiTitle hi))
  link_ [rel_ "icon", mk "type" "image/svg+xml", href_ "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 36 36' fill='none' stroke='%23FF4B26' stroke-width='2' stroke-linejoin='round' stroke-linecap='round'%3E%3Cpath d='M18 4 L31 11 L31 25 L18 32 L5 25 L5 11 Z'/%3E%3Cpath d='M18 18 L31 11 M18 18 L18 32 M18 18 L5 25'/%3E%3C/svg%3E"]
  meta_ [charset_ "utf-8"]
  meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
  meta_ [mk "name" "color-scheme", mk "content" "light dark"]
  ogBlock hi
  link_ [rel_ "preconnect", href_ "https://rsms.me", mk "crossorigin" "anonymous"]
  link_ [rel_ "preconnect", href_ "https://fonts.gstatic.com", mk "crossorigin" "anonymous"]
  link_ [rel_ "preload", href_ "https://rsms.me/inter/font-files/Inter-Regular.woff2?v=4.1", mk "as" "font", mk "type" "font/woff2", mk "crossorigin" "anonymous"]
  link_ [rel_ "preload", href_ "https://rsms.me/inter/font-files/Inter-Medium.woff2?v=4.1", mk "as" "font", mk "type" "font/woff2", mk "crossorigin" "anonymous"]
  link_ [rel_ "preload", href_ "https://fonts.gstatic.com/s/instrumentserif/v5/jizBRFtNs2ka5fXjeivQ4LroWlx-6zUTjg.woff2", mk "as" "font", mk "type" "font/woff2", mk "crossorigin" "anonymous"]
  link_ [rel_ "stylesheet", href_ "https://rsms.me/inter/inter.css", mk "as" "style", mk "onload" "this.onload=null;this.rel='stylesheet'"]
  link_ [rel_ "stylesheet", href_ "https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap", mk "as" "style", mk "onload" "this.onload=null;this.rel='stylesheet'"]
  rawHtml "<noscript><link rel=\"stylesheet\" href=\"https://rsms.me/inter/inter.css\"></link><link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&amp;display=swap\"></link></noscript>"
  link_ [rel_ "preload", mk "as" "style", href_ "/css/style.css"]
  link_ [rel_ "stylesheet", href_ "/css/style.css"]
  link_ [rel_ "preload", mk "as" "script", href_ "/gfx.js"]
  script_ [mk "async" "async", src_ "/gfx.js"] ("" :: Text)
  script_ themeBootScript
  script_ relativeTimeScript
  script_ [defer_ "", src_ "/theme.js"] ("" :: Text)
  script_ [defer_ "", src_ "/cover.js"] ("" :: Text)
  script_ [defer_ "", src_ "/spa.js"] ("" :: Text)
