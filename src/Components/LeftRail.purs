module Components.LeftRail
  ( leftRail
  , desktopMainChrome
  , floatingToc
  ) where

import Prelude

import Components.Logo (cubeLogoLink)
import Data.Array (null)
import Data.Maybe (Maybe(..))
import Luna.Html (Html, attr, unsafeRawHtml)
import Luna.Html as H
import Luna.Html.Events (always_, onClick)
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

-- | Font Awesome–style home glyph for the mobile crumb on `/`.
homeCrumbIcon :: forall i. Html i
homeCrumbIcon =
  unsafeRawHtml
    """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="h-4 w-4 shrink-0 text-neutral-600 dark:text-neutral-300" aria-hidden="true"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
"""

routeCrumbElt :: forall i. Route -> Html i
routeCrumbElt = case _ of
  Home ->
    H.span [ H.classes [ "flex", "items-center" ] ] [ homeCrumbIcon ]
  r ->
    H.span
      [ H.classes [ "truncate", "text-[11px]", "font-medium", "tracking-wide", "text-neutral-500", "dark:text-neutral-400" ] ]
      [ H.text (routeCrumb r) ]

-- | Desktop TOC sidebar (and TOC in the mobile drawer) only for long-form sections that ship headings.
tocSidebarSection :: String -> Boolean
tocSidebarSection s = s == "articles" || s == "collection"

-- | Show the aside / TOC rail when this post has outline headings to navigate.
showTocSidebar :: Route -> Array TocItem -> Boolean
showTocSidebar (SectionPost section _) toc = tocSidebarSection section && not (null toc)
showTocSidebar _ _ = false

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
            [ H.div [ H.classes [ "shrink-0" ] ] [ cubeLogoLink (printRoutePath Home) true ]
            , routeCrumbElt current
            ]
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
                    , "shadow-[0_12px_24px_-8px_rgba(0,0,0,0.25)]"
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

tocBlock :: forall i. Array TocItem -> Maybe String -> Html i
tocBlock items activeId =
  H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
    [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "TOC" ]
    , H.div [ H.classes [ "space-y-0.5" ] ] (map (\item -> tocLink item activeId) items)
    ]

tocLink :: forall i. TocItem -> Maybe String -> Html i
tocLink item activeId =
  H.a
    ( [ H.href ("#" <> item.id)
      , attr "data-toc-id" item.id
      ]
        <>
          [ H.classes
              ( [ "block"
                , "transition-colors"
                , "duration-200"
                , "ease-out"
                ]
                  <> if activeId == Just item.id
                    then [ "text-[#FF4B26]", "decoration-[#FF4B26]" ]
                    else [ "decoration-neutral-300", "text-[#171717]", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]", "dark:text-neutral-200", "dark:hover:text-[#FF6B4A]" ]
                  <> if item.level > 2 then [ "pl-3" ] else []
              )
          ]
    )
    [ H.text ("- " <> item.title) ]

-- | Tabler-style stroke icons (MIT), inlined to avoid an extra font or sprite sheet.
themeSvgSun :: String
themeSvgSun =
  """
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" class="pointer-events-none" aria-hidden="true"><path d="M12 12m-4 0a4 4 0 1 0 8 0a4 4 0 1 0 -8 0"/><path d="M3 12h1m8 -9v1m8 8h1m-9 8v1M5.6 5.6l.7 .7m12.1 -.7l-.7 .7m0 11.4l.7 .7m-12.1 -.7l-.7 .7"/></svg>
"""

themeSvgMoon :: String
themeSvgMoon =
  """
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" class="pointer-events-none" aria-hidden="true"><path d="M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454z"/></svg>
"""

themeModeBtn :: forall i. String -> String -> String -> String -> (String -> i) -> Html i
themeModeBtn mode ariaLabel svg themeMode onThemeMode =
  H.button
    [ attr "type" "button"
    , attr "aria-pressed" (if themeMode == mode then "true" else "false")
    , attr "aria-label" ariaLabel
    , onClick (always_ (onThemeMode mode))
    , H.classes
        [ "theme-mode-btn"
        , "rounded-md"
        , "p-2"
        , "text-neutral-500"
        , "transition-colors"
        , "hover:bg-neutral-100"
        , "hover:text-[#171717]"
        , "dark:text-neutral-400"
        , "dark:hover:bg-neutral-800"
        , "dark:hover:text-neutral-100"
        , "aria-pressed:text-[#FF4B26]"
        , "dark:aria-pressed:text-[#FF6B4A]"
        ]
    ]
    [ unsafeRawHtml svg ]

-- | Theme button `aria-label` values must stay aligned with `patchSsrThemeButtons` in `Main.js`.
themeToggleGroup :: forall i. String -> (String -> i) -> Html i
themeToggleGroup themeMode onThemeMode =
  H.div
    [ H.classes [ "flex", "items-center", "justify-center", "gap-0.5" ]
    , attr "data-theme-controls" ""
    , attr "role" "group"
    , attr "aria-label" "Theme"
    ]
    [ themeModeBtn "light" "Use light theme" themeSvgSun themeMode onThemeMode
    , themeModeBtn "dark" "Use dark theme" themeSvgMoon themeMode onThemeMode
    ]

themeToggle :: forall i. String -> (String -> i) -> Html i
themeToggle themeMode onThemeMode =
  H.div
    [ H.classes [ "shrink-0", "pt-4" ] ]
    [ themeToggleGroup themeMode onThemeMode ]

themeToggleInline :: forall i. String -> (String -> i) -> Html i
themeToggleInline themeMode onThemeMode =
  H.div [ H.classes [ "shrink-0" ] ] [ themeToggleGroup themeMode onThemeMode ]

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
