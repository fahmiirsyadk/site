module Components.LeftRail
  ( leftRail
  , desktopMainChrome
  , floatingToc
  ) where

import Prelude

import Components.Logo (cubeLogoLink)
import Components.Toc (showTocSidebar, tocBlock)
import Components.ThemeToggle (themeToggle, themeToggleInline)
import Data.Maybe (Maybe)
import Luna.Html (Html, attr)
import Luna.Html as H
import Routes (printRoutePath)
import Types (Route(..), TocItem)

leftRail :: forall i. Route -> Array TocItem -> Maybe String -> String -> (String -> i) -> Html i
leftRail current toc activeTocId themeMode onThemeMode =
  H.div
    [ H.classes [ "contents" ] ]
    [ mobileTopNav current toc activeTocId themeMode onThemeMode ]

routeCrumb :: Route -> String
routeCrumb = case _ of
  Home -> "home"
  About -> "about"
  SectionIndex s -> s
  SectionPost section slug -> section <> " · " <> slug

routeCrumbElt :: forall i. Route -> Html i
routeCrumbElt = case _ of
  Home ->
    H.span [] []
  r ->
    H.span
      [ H.classes [ "truncate", "text-[11px]", "font-medium", "tracking-wide", "text-neutral-500", "dark:text-neutral-400" ] ]
      [ H.text (routeCrumb r) ]

railScrollable :: forall i. Route -> Array TocItem -> Maybe String -> Html i
railScrollable current toc activeTocId =
  H.div
    [ H.classes [ "flex", "min-h-0", "flex-1", "flex-col", "gap-6" ] ]
    [ if showTocSidebar current toc then tocBlock toc activeTocId else defaultRail current ]

-- | Desktop header: logo, primary links, theme (same on every page; mobile uses the drawer).
desktopMainChrome :: forall i. Route -> String -> (String -> i) -> Html i
desktopMainChrome current themeMode onThemeMode =
  H.div
    [ H.classes
        [ "hidden"
        , "md:flex"
        , "w-full"
        , "flex-wrap"
        , "items-center"
        , "justify-between"
        , "gap-4"
        , "pb-4"
        , "mb-6"
        ]
    ]
    [ H.div [ H.classes [ "flex", "min-w-0", "flex-1", "flex-wrap", "items-center", "gap-x-5", "gap-y-2" ] ]
        [ H.div [ H.classes [ "shrink-0" ] ] [ cubeLogoLink (printRoutePath Home) true ]
        , H.div [ H.classes [ "flex", "flex-wrap", "items-center", "gap-x-4", "gap-y-1" ] ]
            [ navLink (SectionIndex "projects") "projects" current
            , navLink (SectionIndex "articles") "articles" current
            , navLink (SectionIndex "til") "TIL" current
            , H.a
                [ H.href "#"
                , H.classes
                    [ "text-[12px]"
                    , "underline"
                    , "underline-offset-[3px]"
                    , "decoration-neutral-300"
                    , "text-[#171717]"
                    , "transition-colors"
                    , "duration-200"
                    , "ease-out"
                    , "hover:text-[#FF4B26]"
                    , "hover:decoration-[#FF4B26]"
                    , "dark:text-neutral-200"
                    , "dark:hover:text-[#FF6B4A]"
                    ]
                ]
                [ H.text "fragmentof.me" ]
            , navLink About "about me" current
            ]
        ]
    , themeToggleInline themeMode onThemeMode
    ]

mobileTopNav :: forall i. Route -> Array TocItem -> Maybe String -> String -> (String -> i) -> Html i
mobileTopNav current toc activeTocId themeMode onThemeMode =
  H.nav
    [ H.classes
        [ "mobile-site-nav"
        , "fixed"
        , "left-0"
        , "right-0"
        , "top-0"
        , "z-50"
        , "flex"
        , "md:hidden"
        , "flex-col"
        , "border-b"
        , "border-[#E5E5E5]"
        , "bg-[#FAFAFA]/95"
        , "backdrop-blur-sm"
        , "dark:border-neutral-800"
        , "dark:bg-neutral-950/95"
        , "[--mobile-toolbar-h:calc(2.25rem+1.25rem+env(safe-area-inset-top,0px))]"
        ]
    ]
    [ H.div
        [ H.classes
            [ "flex"
            , "min-h-[var(--mobile-toolbar-h)]"
            , "shrink-0"
            , "items-center"
            , "justify-between"
            , "gap-3"
            , "px-4"
            , "py-2.5"
            , "pt-[max(0.625rem,env(safe-area-inset-top))]"
            ]
        ]
        [ H.div [ H.classes [ "flex", "min-w-0", "flex-1", "items-center", "gap-3" ] ]
            ( [ H.div [ H.classes [ "shrink-0" ] ] [ cubeLogoLink (printRoutePath Home) true ] ]
                <> if current == Home then [] else [ routeCrumbElt current ]
            )
        , H.details
            [ H.classes [ "shrink-0" ] ]
            [ H.summary
                [ attr "aria-label" "Open site menu"
                , H.classes
                    [ "flex"
                    , "list-none"
                    , "cursor-pointer"
                    , "items-center"
                    , "justify-center"
                    , "p-1"
                    , "text-neutral-600"
                    , "transition-colors"
                    , "hover:text-[#FF4B26]"
                    , "dark:text-neutral-400"
                    , "dark:hover:text-[#FF6B4A]"
                    , "[&::-webkit-details-marker]:hidden"
                    ]
                ]
                [ menuButtonIcon ]
            , H.div
                [ H.classes
                    [ "fixed"
                    , "left-0"
                    , "right-0"
                    , "top-[var(--mobile-toolbar-h)]"
                    , "z-40"
                    , "max-h-[min(75dvh,calc(100dvh-var(--mobile-toolbar-h)-0.5rem))]"
                    , "overflow-y-auto"
                    , "border-b"
                    , "border-[#E5E5E5]"
                    , "bg-[#FAFAFA]"
                    , "px-4"
                    , "pb-6"
                    , "pt-4"
                    , "dark:border-neutral-800"
                    , "dark:bg-neutral-950"
                    ]
                ]
                [ railScrollable current toc activeTocId
                , themeToggle themeMode onThemeMode
                ]
            ]
        ]
    ]

menuButtonIcon :: forall i. Html i
menuButtonIcon =
  H.span
    [ H.classes [ "flex", "h-5", "w-5", "flex-col", "items-center", "justify-center", "gap-1" ]
    , attr "aria-hidden" "true"
    ]
    [ H.span [ H.classes [ "block", "h-0.5", "w-4", "rounded-full", "bg-current" ] ] []
    , H.span [ H.classes [ "block", "h-0.5", "w-4", "rounded-full", "bg-current" ] ] []
    , H.span [ H.classes [ "block", "h-0.5", "w-4", "rounded-full", "bg-current" ] ] []
    ]

-- | Fixed-position TOC overlay anchored to the right edge of the viewport (large screens only; hidden md–lg).
-- | Rendered inside the scroll container so it doesn't participate in the flex row.
floatingToc :: forall i. Route -> Array TocItem -> Maybe String -> Html i
floatingToc current toc activeTocId =
  if showTocSidebar current toc then
    H.aside
      [ H.classes
          [ "hidden"
          , "lg:flex"
          , "fixed"
          , "right-4"
          , "top-14"
          , "z-30"
          , "w-[min(13rem,22vw)]"
          , "max-h-[calc(100dvh-5rem)]"
          , "flex-col"
          , "overflow-y-auto"
          , "overflow-x-hidden"
          , "py-1"
          ]
      ]
      [ tocBlock toc activeTocId ]
  else
    H.div [] []

defaultRail :: forall i. Route -> Html i
defaultRail current =
  H.div [ H.classes [ "flex", "flex-col", "gap-7" ] ]
    [ H.p [ H.classes [ "mb-1", "text-[12px]", "leading-[1.7]", "text-[#171717]", "dark:text-neutral-200" ] ]
        [ H.text "Notes, projects, and experiments in public" ]
    , H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
        [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "MENU" ]
        , navLink (SectionIndex "projects") "projects" current
        , navLink (SectionIndex "articles") "articles" current
        , navLink (SectionIndex "til") "TIL" current
        ]
    , H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
        [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "LAB" ]
        , H.a [ H.href "#", H.classes [ "underline", "underline-offset-[3px]", "decoration-neutral-300", "text-[#171717]", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]", "dark:text-neutral-200", "dark:hover:text-[#FF6B4A]" ] ] [ H.text "fragmentof.me" ]
        ]
    , H.div [ H.classes [ "flex", "flex-col", "gap-1", "pb-1" ] ]
        [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "SOCIAL" ]
        , navLink About "about me" current
        ]
    ]

navLink :: forall i. Route -> String -> Route -> Html i
navLink route label current =
  H.a
    [ H.href (printRoutePath route)
    , H.classes
        $ [ "underline", "underline-offset-[3px]", "decoration-neutral-300", "text-[#171717]", "transition-colors", "duration-200", "ease-out", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]", "dark:text-neutral-200", "dark:hover:text-[#FF6B4A]" ]
        <> if current == route then [ "text-[#FF4B26]", "decoration-[#FF4B26]" ] else []
    ]
    [ H.text label ]
