{-# LANGUAGE OverloadedStrings #-}
module Site.Footer (siteFooter) where

import Lucid
import Site.Theme (mk)

siteFooter :: Html ()
siteFooter =
  div_ [class_ "flex w-full min-h-0 flex-1 flex-col self-stretch mt-10"] $ do
    div_
      [ mk "id" "sea-footer"
      , class_ "relative flex min-h-0 w-[calc(100%+4rem)] -mx-8 max-w-none flex-1 overflow-hidden rounded-lg bg-transparent dark:bg-[#171717]"
      , style_ "min-height:clamp(240px,34vh,420px);"
      ] $ do
        canvas_
          [ mk "id" "sea-canvas"
          , mk "aria-label" "Sea animation"
          , class_ "block w-full bg-transparent"
          ] (mempty :: Html ())
