{-# LANGUAGE OverloadedStrings #-}
module Site.Boot (bootOverlay) where

import Lucid
import Data.Text (Text)
import Site.Theme (mk)

bootOverlay :: Html ()
bootOverlay =
  div_
    [ mk "id" "gfx-boot-overlay"
    , class_ "gfx-boot-overlay pointer-events-auto fixed inset-0 z-[2000] overflow-hidden bg-transparent text-white"
    , mk "role" "status"
    , mk "aria-label" "Loading graphics"
    ] $ do
      canvas_ [ mk "id" "gfx-boot-canvas"
              , class_ "absolute inset-0 z-[2] block h-screen w-screen bg-[#ff0000] [image-rendering:pixelated] [image-rendering:crisp-edges] pointer-events-none"
              , mk "aria-hidden" "true"
              ] (mempty :: Html ())
      div_ [ class_ "absolute inset-0 z-[3] pointer-events-none" ] $
        div_ [ mk "id" "gfx-boot-chrome"
             , class_ "absolute inset-0 text-white [text-shadow:none] isolate [transform:translateZ(0)] font-instrument"
             ] $ do
          div_ [ class_ "absolute top-[46px] left-0 origin-top-left -rotate-90 -translate-x-full text-[12px] tracking-[0.04em] font-medium whitespace-nowrap max-md:top-[34px] max-md:text-[11px]"
               ] $ do
            toHtml ("GRAPHICS BOOT " :: Text)
            span_ [ mk "id" "gfx-boot-counter" ] (toHtml ("00" :: Text))
            toHtml ("/50" :: Text)
          div_ [ class_ "absolute left-8 bottom-7 text-[clamp(44px,8vw,108px)] leading-[0.82] font-medium tracking-[-0.03em] uppercase max-md:left-5 max-md:bottom-[22px] max-md:text-[clamp(32px,11vw,56px)]"
               ] $
            span_ [ mk "id" "gfx-boot-progress" ] (toHtml ("0%" :: Text))