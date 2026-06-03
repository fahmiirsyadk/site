module Components.ThemeToggle
  ( themeToggleGroup
  , themeToggle
  , themeToggleInline
  ) where

import Prelude

import Luna.Html (Html, attr, unsafeRawHtml)
import Luna.Html as H
import Luna.Html.Events (always_, onClick)
import Types (ThemeMode(..))

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

themeModeBtn :: forall i. ThemeMode -> String -> String -> ThemeMode -> (ThemeMode -> i) -> Html i
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

-- | Theme button `aria-label` values must stay aligned with `patchSsrThemeButtons` in `FFI.js`.
themeToggleGroup :: forall i. ThemeMode -> (ThemeMode -> i) -> Html i
themeToggleGroup themeMode onThemeMode =
  H.div
    [ H.classes [ "flex", "items-center", "justify-center", "gap-0.5" ]
    , attr "data-theme-controls" ""
    , attr "role" "group"
    , attr "aria-label" "Theme"
    ]
    [ themeModeBtn Light "Use light theme" themeSvgSun themeMode onThemeMode
    , themeModeBtn Dark "Use dark theme" themeSvgMoon themeMode onThemeMode
    ]

themeToggle :: forall i. ThemeMode -> (ThemeMode -> i) -> Html i
themeToggle themeMode onThemeMode =
  H.div
    [ H.classes [ "shrink-0", "pt-4" ] ]
    [ themeToggleGroup themeMode onThemeMode ]

themeToggleInline :: forall i. ThemeMode -> (ThemeMode -> i) -> Html i
themeToggleInline themeMode onThemeMode =
  H.div [ H.classes [ "shrink-0" ] ] [ themeToggleGroup themeMode onThemeMode ]
