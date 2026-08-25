module Component.Icon where

import Prelude

import Foldkit.Html as HH
import Foldkit.Html.Prop as HP

github :: forall message. HH.Child message
github =
  HH.svg
    [ HP.ariaHidden true
    , HP.xmlns "http://www.w3.org/2000/svg"
    , HP.fill "none"
    , HP.viewBox "0 0 24 24"
    , HP.class_ "inline-block h-3 w-3 align-[-0.15em]"
    ]
    [ HH.path
        [ HP.d "M12 2.5a9.5 9.5 0 0 0-3 18.51c.475.09.65-.206.65-.457v-1.79c-2.65.576-3.2-1.12-3.2-1.12-.43-1.1-1.05-1.4-1.05-1.4-.86-.59.065-.58.065-.58.95.067 1.45.98 1.45.98.85 1.45 2.23 1.03 2.77.79.085-.615.33-1.03.6-1.27-2.12-.24-4.35-1.06-4.35-4.72 0-1.04.37-1.89.98-2.56-.1-.24-.42-1.21.09-2.52 0 0 .8-.26 2.62.98a9.1 9.1 0 0 1 4.77 0c1.82-1.24 2.62-.98 2.62-.98.51 1.31.19 2.28.09 2.52.61.67.98 1.52.98 2.56 0 3.67-2.23 4.47-4.36 4.71.34.3.64.87.64 1.76v2.6c0 .25.17.55.66.46A9.5 9.5 0 0 0 12 2.5Z"
        , HP.fill "currentColor"
        , HP.fillRule "evenodd"
        , HP.clipRule "evenodd"
        ] []
    ]

mail :: forall message. HH.Child message
mail =
  HH.svg
    [ HP.ariaHidden true
    , HP.xmlns "http://www.w3.org/2000/svg"
    , HP.fill "none"
    , HP.viewBox "0 0 24 24"
    , HP.stroke "currentColor"
    , HP.strokeWidth "1.75"
    , HP.class_ "inline-block h-3 w-3 align-[-0.15em]"
    ]
    [ HH.path
        [ HP.d "m4 6.5 8 5.5 8-5.5M5 5h14a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z"
        , HP.strokeLinecap "round"
        , HP.strokeLinejoin "round"
        ] []
    ]

filled :: forall message. Array String -> String -> HH.Child message
filled paths className =
  HH.svg
    [ HP.ariaHidden true
    , HP.class_ className
    , HP.xmlns "http://www.w3.org/2000/svg"
    , HP.fill "none"
    , HP.viewBox "0 0 24 24"
    ]
    (map
      (\pathData -> HH.path
        [ HP.d pathData
        , HP.fill "currentColor"
        , HP.fillRule "evenodd"
        , HP.clipRule "evenodd"
        ] [])
      paths)

outlined :: forall message. String -> String -> HH.Child message
outlined pathData className =
  HH.svg
    [ HP.ariaHidden true
    , HP.class_ className
    , HP.xmlns "http://www.w3.org/2000/svg"
    , HP.fill "none"
    , HP.viewBox "0 0 24 24"
    , HP.stroke "currentColor"
    , HP.strokeWidth "1.75"
    ]
    [ HH.path
        [ HP.d pathData
        , HP.strokeLinecap "round"
        , HP.strokeLinejoin "round"
        ] []
    ]
