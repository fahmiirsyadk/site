{-# LANGUAGE OverloadedStrings #-}
module Site.Component
  ( logoLink
  , navLink
  , themeModeBtn
  , themeToggleGroup
  , themeToggle
  , themeToggleInline
  , leaderRow
  , postPreviewRow
  ) where

import Lucid
import Data.Text (Text)
import qualified Data.Text as T
import Site.Theme (mk, rawHtml, sunSvg, moonSvg)

logoLink :: Text -> Text -> Bool -> Html ()
logoLink href _ compact =
  a_ [href_ href, class_ "no-underline block outline-none", mk "aria-label" "Home"] $
    div_
      [ mk "data-cube-logo-host" "true"
      , mk "data-logo-px" (if compact then "36" else "60")
      , class_ $ T.intercalate " "
          [ "flex items-center justify-center"
          , if compact then "h-9 w-9" else "h-[60px] w-[60px]"
          ]
      ]
      mempty

navLink :: Text -> Text -> Bool -> Html ()
navLink href label active =
  a_ [ href_ href
     , class_ $ "underline underline-offset-[3px] decoration-neutral-300 text-[#171717] transition-colors duration-200 ease-out hover:text-[#FF4B26] hover:decoration-[#FF4B26] dark:text-neutral-200 dark:hover:text-[#FF6B4A]"
                 <> if active then " text-[#FF4B26] decoration-[#FF4B26]" else ""
     ]
     (toHtml label)

themeModeBtn :: Text -> Text -> Text -> Bool -> Html ()
themeModeBtn label svg mode pressed =
  button_
    [ mk "type" "button"
    , mk "aria-pressed" (if pressed then "true" else "false")
    , mk "aria-label" label
    , mk "data-theme-set" mode
    , class_ "theme-mode-btn rounded-md p-2 text-neutral-500 transition-colors hover:bg-neutral-100 hover:text-[#171717] dark:text-neutral-400 dark:hover:bg-neutral-800 dark:hover:text-neutral-100 aria-pressed:text-[#FF4B26] dark:aria-pressed:text-[#FF6B4A]"
    ]
    (rawHtml svg)

themeToggleGroup :: Bool -> Html ()
themeToggleGroup isDark =
  div_ [ class_ "flex items-center justify-center gap-0.5"
       , mk "data-theme-controls" ""
       , mk "role" "group"
       , mk "aria-label" "Theme"
       ] $ do
          themeModeBtn "Use light theme" sunSvg "light" (not isDark)
          themeModeBtn "Use dark theme" moonSvg "dark" isDark

themeToggle :: Bool -> Html ()
themeToggle isDark =
  div_ [class_ "shrink-0 pt-4"] (themeToggleGroup isDark)

themeToggleInline :: Bool -> Html ()
themeToggleInline isDark =
  div_ [class_ "shrink-0"] (themeToggleGroup isDark)

leaderRow :: Text -> Text -> Html ()
leaderRow _ _ =
  span_ [class_ "min-h-px min-w-[1.5rem] flex-1 border-b border-solid border-neutral-300 dark:border-neutral-600"] mempty

postPreviewRow :: Text -> Text -> Text -> Text -> Html ()
postPreviewRow href titleText isoDate displayText =
  div_ [class_ "flex w-full items-center gap-3 py-2 text-normal leading-[1.7]"] $ do
    a_ [ href_ href
       , class_ "shrink-0 font-instrument text-[16px] leading-[1.3] text-[#171717] no-underline hover:text-[#FF4B26] dark:text-neutral-200 dark:hover:text-[#FF6B4A]"
       ] (toHtml titleText)
    leaderRow titleText displayText
    span_ [ class_ "shrink-0 whitespace-nowrap text-right text-neutral-500"
          , mk "data-relative-date" isoDate
          ] (toHtml displayText)
