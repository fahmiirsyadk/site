module Component.DitheredImage where

import Prelude

import Foldkit.Html as HH
import Foldkit.Mount (MountAction)
import Foldkit.Html.Prop as HP

type Input message =
  { src :: String
  , alt :: String
  , containerClassName :: String
  , className :: String
  , mount :: MountAction message
  }

view :: forall message. Input message -> HH.Child message
view input =
  HH.div
    [ HP.class_ ("dithered-image relative overflow-hidden " <> input.containerClassName)
    , HP.dataAttribute "dithered-image" ""
    , HP.onMount { action: input.mount }
    ]
    [ HH.img
        [ HP.src input.src
        , HP.alt input.alt
        , HP.dataAttribute "dithered-source" ""
        , HP.loading "eager"
        , HP.class_ "dithered-image-source absolute inset-0 h-full w-full object-cover"
        ] []
    , HH.canvas
        [ HP.ariaHidden true
        , HP.dataAttribute "dithered-canvas" ""
        , HP.class_ input.className
        ] []
    ]
