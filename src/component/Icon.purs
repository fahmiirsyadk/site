module Component.Icon where

import Prelude

import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Prop as HP

github :: forall message. FK.Child message
github =
  HH.svg
    [ HP.attr "aria-hidden" "true"
    , HP.attr "xmlns" "http://www.w3.org/2000/svg"
    , HP.attr "fill" "none"
    , HP.attr "viewBox" "0 0 24 24"
    , HP.class_ "inline-block h-3 w-3 align-[-0.15em]"
    ]
    [ HH.path
        [ HP.attr "d" "M12 2.5a9.5 9.5 0 0 0-3 18.51c.475.09.65-.206.65-.457v-1.79c-2.65.576-3.2-1.12-3.2-1.12-.43-1.1-1.05-1.4-1.05-1.4-.86-.59.065-.58.065-.58.95.067 1.45.98 1.45.98.85 1.45 2.23 1.03 2.77.79.085-.615.33-1.03.6-1.27-2.12-.24-4.35-1.06-4.35-4.72 0-1.04.37-1.89.98-2.56-.1-.24-.42-1.21.09-2.52 0 0 .8-.26 2.62.98a9.1 9.1 0 0 1 4.77 0c1.82-1.24 2.62-.98 2.62-.98.51 1.31.19 2.28.09 2.52.61.67.98 1.52.98 2.56 0 3.67-2.23 4.47-4.36 4.71.34.3.64.87.64 1.76v2.6c0 .25.17.55.66.46A9.5 9.5 0 0 0 12 2.5Z"
        , HP.attr "fill" "currentColor"
        , HP.attr "fill-rule" "evenodd"
        , HP.attr "clip-rule" "evenodd"
        ] []
    ]

mail :: forall message. FK.Child message
mail =
  HH.svg
    [ HP.attr "aria-hidden" "true"
    , HP.attr "xmlns" "http://www.w3.org/2000/svg"
    , HP.attr "fill" "none"
    , HP.attr "viewBox" "0 0 24 24"
    , HP.attr "stroke" "currentColor"
    , HP.attr "stroke-width" "1.75"
    , HP.class_ "inline-block h-3 w-3 align-[-0.15em]"
    ]
    [ HH.path
        [ HP.attr "d" "m4 6.5 8 5.5 8-5.5M5 5h14a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z"
        , HP.attr "stroke-linecap" "round"
        , HP.attr "stroke-linejoin" "round"
        ] []
    ]

filled :: forall message. Array String -> String -> FK.Child message
filled paths className =
  HH.svg
    [ HP.attr "aria-hidden" "true"
    , HP.attr "class" className
    , HP.attr "xmlns" "http://www.w3.org/2000/svg"
    , HP.attr "fill" "none"
    , HP.attr "viewBox" "0 0 24 24"
    ]
    (map
      (\pathData -> HH.path
        [ HP.attr "d" pathData
        , HP.attr "fill" "currentColor"
        , HP.attr "fill-rule" "evenodd"
        , HP.attr "clip-rule" "evenodd"
        ] [])
      paths)

outlined :: forall message. String -> String -> FK.Child message
outlined pathData className =
  HH.svg
    [ HP.attr "aria-hidden" "true"
    , HP.attr "class" className
    , HP.attr "xmlns" "http://www.w3.org/2000/svg"
    , HP.attr "fill" "none"
    , HP.attr "viewBox" "0 0 24 24"
    , HP.attr "stroke" "currentColor"
    , HP.attr "stroke-width" "1.75"
    ]
    [ HH.path
        [ HP.attr "d" pathData
        , HP.attr "stroke-linecap" "round"
        , HP.attr "stroke-linejoin" "round"
        ] []
    ]
