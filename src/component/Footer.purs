module Component.Footer where

import Component.Icon as Icon
import Domain.Theme as Theme
import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Prop as HP

moonIcon :: forall message. FK.Child message
moonIcon = Icon.outlined "M21 15.25A9 9 0 1 1 8.75 3a9 9 0 0 0 12.25 12.25Z" "footer-theme-icon"

sunIcon :: forall message. FK.Child message
sunIcon = Icon.outlined "M12 3v1.5M12 19.5V21M3 12h1.5M19.5 12H21M5.64 5.64 6.7 6.7M17.3 17.3l1.06 1.06M18.36 5.64 17.3 6.7M6.7 17.3l-1.06 1.06M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z" "footer-theme-icon"

themeToggle :: forall message. { theme :: Theme.Theme, message :: message } -> FK.Child message
themeToggle input =
  HH.button
    [ HP.attr "type" "button"
    , HP.onClick { message: input.message }
    , HP.attr "aria-label" (toggleLabel input.theme)
    , HP.attr "title" (toggleLabel input.theme)
    , HP.class_ "footer-theme-toggle"
    ] [ themeIcon input.theme ]

toggleLabel :: Theme.Theme -> String
toggleLabel theme = case theme of
  Theme.Light -> "Use dark theme"
  Theme.Dark -> "Use light theme"

themeIcon :: forall message. Theme.Theme -> FK.Child message
themeIcon theme = case theme of
  Theme.Light -> moonIcon
  Theme.Dark -> sunIcon
