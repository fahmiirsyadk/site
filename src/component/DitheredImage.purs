module Component.DitheredImage where

import Prelude

import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Mount (MountAction)
import Interop.Foldkit.Prop as HP

type Input message =
  { src :: String
  , alt :: String
  , containerClassName :: String
  , className :: String
  , mount :: MountAction message
  }

view :: forall message. Input message -> FK.Child message
view input =
  HH.div
    [ HP.class_ ("dithered-image relative overflow-hidden " <> input.containerClassName)
    , HP.attr "data-dithered-image" ""
    , HP.onMount { action: input.mount }
    ]
    [ HH.img
        [ HP.attr "src" input.src
        , HP.attr "alt" input.alt
        , HP.attr "data-dithered-source" ""
        , HP.attr "loading" "eager"
        , HP.class_ "dithered-image-source absolute inset-0 h-full w-full object-cover"
        ] []
    , HH.canvas
        [ HP.attr "aria-hidden" "true"
        , HP.attr "data-dithered-canvas" ""
        , HP.class_ input.className
        ] []
    ]
