module Page.NotFound where

import Prelude

import App.Route as Route
import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Prop as HP

type Input =
  { path :: String
  }

view :: forall message. Input -> FK.Child message
view input =
  HH.div [ HP.class_ "space-y-5" ]
    [ HH.h1 [ HP.class_ "text-[12px] font-semibold text-[#FF4B26]" ] [ HH.text "404" ]
    , HH.p [ HP.class_ "text-[12px] text-neutral-600 dark:text-neutral-400" ]
        [ HH.text ("The path \"" <> input.path <> "\" was not found.") ]
    , HH.a
        [ HP.attr "href" (Route.homePath unit)
        , HP.class_ "text-[#FF4B26] underline"
        ]
        [ HH.text "Go home" ]
    ]
