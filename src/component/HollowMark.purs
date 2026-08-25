module Component.HollowMark where

import Foldkit.Html as HH
import Foldkit.Mount (MountAction)
import Foldkit.Html.Prop as HP

type Input message =
  { interaction :: String
  , mount :: MountAction message
  }

view :: forall message. Input message -> HH.Child message
view input =
  HH.canvas
    [ HP.role_ "img"
    , HP.ariaLabel "Faah split lunar sphere"
    , HP.dataAttribute "lab-interaction" input.interaction
    , HP.class_ "hollow-mark"
    , HP.onMount { action: input.mount }
    ]
    []
