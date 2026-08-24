module Component.HollowMark where

import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Mount (MountAction)
import Interop.Foldkit.Prop as HP

type Input message =
  { interaction :: String
  , mount :: MountAction message
  }

view :: forall message. Input message -> FK.Child message
view input =
  HH.canvas
    [ HP.attr "role" "img"
    , HP.attr "aria-label" "Faah split lunar sphere"
    , HP.attr "data-lab-interaction" input.interaction
    , HP.class_ "hollow-mark"
    , HP.onMount { action: input.mount }
    ]
    []
