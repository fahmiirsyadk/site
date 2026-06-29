{-# LANGUAGE OverloadedStrings #-}
module Site.Layout (baseLayout) where

import Lucid
import Site.Head (renderHead)
import Site.Nav (mobileNav, desktopNav)
import Site.Footer (siteFooter)
import Site.Boot (bootOverlay)
import Site.Theme (mk)
import Site.Types (HeadInfo(..))

baseLayout :: HeadInfo -> Bool -> Html () -> Html ()
baseLayout hi isDark bodyHtml = html_ [lang_ "en", style_ "color-scheme: light;"] $ do
  renderHead hi
  body_ [class_ "min-h-screen bg-[#F5F5F5] text-[#171717] antialiased dark:bg-neutral-950 dark:text-neutral-100"] $ do
    div_ [class_ "flex min-h-screen w-full flex-col md:h-screen md:max-h-screen md:flex-row md:overflow-hidden"] $ do
      div_ [class_ "contents"] (mobileNav (hiPath hi) isDark)
      main_ [class_ "flex h-full min-h-0 min-w-0 flex-1 flex-col border-t border-[#E5E5E5] bg-white dark:border-neutral-800 dark:bg-neutral-900 md:border-t-0 max-md:pt-[calc(5.5rem+env(safe-area-inset-top,0px))]"] $
        div_ [ class_ "flex h-full min-h-0 overflow-y-auto min-h-full w-full flex-1 flex-col items-center justify-start bg-white dark:bg-neutral-900 px-8 pt-6 max-md:pt-4 md:pt-14 pb-0"
             , mk "id" "content-scroll"
             ] $ do
          div_ [class_ "w-full max-w-3xl text-left"] $ do
            desktopNav (hiPath hi) isDark
            div_ [mk "id" "page-view"] bodyHtml
          siteFooter
    bootOverlay
