{-# LANGUAGE OverloadedStrings #-}
module Site.Nav
  ( mobileNav
  , desktopNav
  , drawerContent
  ) where

import Lucid
import Data.Text (Text)
import Site.Component (logoLink, navLink, themeToggle, themeToggleInline)
import Site.Theme (mk, rawHtml, menuButtonIconSvg)

drawerGroup :: Text -> [Html ()] -> Html ()
drawerGroup label links =
  div_ [class_ "flex flex-col gap-1"] $ do
    p_ [class_ "mb-1 text-[10px] font-medium uppercase tracking-[0.07em] text-neutral-500"] (toHtml label)
    mapM_ id links

drawerContent :: Text -> Html ()
drawerContent currentHref =
  div_ [class_ "flex min-h-0 flex-1 flex-col gap-6"] $ do
    div_ [class_ "flex flex-col gap-7"] $ do
      p_ [class_ "mb-1 text-[12px] leading-[1.7] text-[#171717] dark:text-neutral-200"] "Notes, projects, and experiments in public"
      drawerGroup "MENU"
        [ navLink "/projects" "projects" (currentHref == "/projects")
        , navLink "/articles" "articles" (currentHref == "/articles")
        , navLink "/til" "TIL" (currentHref == "/til")
        ]
      drawerGroup "LAB"
        [ a_ [ href_ "#"
             , class_ "underline underline-offset-[3px] decoration-neutral-300 text-[#171717] hover:text-[#FF4B26] hover:decoration-[#FF4B26] dark:text-neutral-200 dark:hover:text-[#FF6B4A]"
             ] "fragmentof.me"
        ]
      div_ [class_ "flex flex-col gap-1 pb-1"] $ do
        p_ [class_ "mb-1 text-[10px] font-medium uppercase tracking-[0.07em] text-neutral-500"] "SOCIAL"
        navLink "/about" "about me" (currentHref == "/about")

mobileNav :: Text -> Bool -> Html ()
mobileNav currentHref isDark =
  nav_ [ mk "data-site-nav" ""
       , class_ "mobile-site-nav fixed left-0 right-0 top-0 z-50 flex md:hidden flex-col border-b border-[#E5E5E5] bg-[#FAFAFA]/95 backdrop-blur-sm dark:border-neutral-800 dark:bg-neutral-950/95 [--mobile-toolbar-h:calc(2.25rem+1.25rem+env(safe-area-inset-top,0px))]"
       ] $ do
    div_ [class_ "flex min-h-[var(--mobile-toolbar-h)] shrink-0 items-center justify-between gap-3 px-4 py-2.5 pt-[max(0.625rem,env(safe-area-inset-top))]"] $ do
      div_ [class_ "flex min-w-0 flex-1 items-center gap-3"] $
        div_ [class_ "shrink-0"] (logoLink "/" "Home" True)
      div_ [class_ "shrink-0"] $ details_ [] $ do
        summary_
          [ mk "aria-label" "Open site menu"
          , class_ "flex list-none cursor-pointer items-center justify-center p-1 text-neutral-600 transition-colors hover:text-[#FF4B26] dark:text-neutral-400 dark:hover:text-[#FF6B4A] [&::-webkit-details-marker]:hidden"
          ] (rawHtml menuButtonIconSvg)
        div_ [ class_ "fixed left-0 right-0 top-[var(--mobile-toolbar-h)] z-40 max-h-[min(75dvh,calc(100dvh-var(--mobile-toolbar-h)-0.5rem))] overflow-y-auto border-b border-[#E5E5E5] bg-[#FAFAFA] px-4 pb-6 pt-4 dark:border-neutral-800 dark:bg-neutral-950"
             ] $ do
          drawerContent currentHref
          themeToggle isDark

desktopNav :: Text -> Bool -> Html ()
desktopNav currentHref isDark =
  div_ [ mk "data-site-nav" ""
       , class_ "hidden w-full flex-wrap items-center justify-between gap-4 pb-4 mb-6 md:flex"
       ] $ do
    div_ [class_ "flex min-w-0 flex-1 flex-wrap items-center gap-x-5 gap-y-2"] $ do
      div_ [class_ "shrink-0"] (logoLink "/" "Home" True)
      div_ [class_ "flex flex-wrap items-center gap-x-4 gap-y-1"] $ do
        navLink "/projects" "projects" (currentHref == "/projects")
        navLink "/articles" "articles" (currentHref == "/articles")
        navLink "/til" "TIL" (currentHref == "/til")
        a_ [ href_ "#"
           , class_ "text-[12px] underline underline-offset-[3px] decoration-neutral-300 text-[#171717] transition-colors duration-200 ease-out hover:text-[#FF4B26] hover:decoration-[#FF4B26] dark:text-neutral-200 dark:hover:text-[#FF6B4A]"
           ] "fragmentof.me"
        navLink "/about" "about me" (currentHref == "/about")
    themeToggleInline isDark
