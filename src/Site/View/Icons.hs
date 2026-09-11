-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The inline SVG set, ported from the source's @Component.Icon@ plus the
-- post action icons. Pure, like every view module.
module Site.View.Icons
  ( githubIcon
  , mailIcon
  , homeArrowIcon
  , chainLinkIcon
  , checkIcon
  , sunIcon
  , moonIcon
  ) where
-----------------------------------------------------------------------------
import           Miso (View)
import qualified Miso.Svg.Element as S
import qualified Miso.Svg.Property as SP
import           Miso.Html.Property as P
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
githubIcon :: View context model action
githubIcon =
  S.svg_
    [ P.aria_ "hidden" "true"
    , P.xmlns_ "http://www.w3.org/2000/svg"
    , SP.fill_ "none"
    , SP.viewBox_ "0 0 24 24"
    , P.class_ "inline-block h-3 w-3 align-[-0.15em]"
    ]
    [ S.path_
        [ SP.d_ "M12 2.5a9.5 9.5 0 0 0-3 18.51c.475.09.65-.206.65-.457v-1.79c-2.65.576-3.2-1.12-3.2-1.12-.43-1.1-1.05-1.4-1.05-1.4-.86-.59.065-.58.065-.58.95.067 1.45.98 1.45.98.85 1.45 2.23 1.03 2.77.79.085-.615.33-1.03.6-1.27-2.12-.24-4.35-1.06-4.35-4.72 0-1.04.37-1.89.98-2.56-.1-.24-.42-1.21.09-2.52 0 0 .8-.26 2.62.98a9.1 9.1 0 0 1 4.77 0c1.82-1.24 2.62-.98 2.62-.98.51 1.31.19 2.28.09 2.52.61.67.98 1.52.98 2.56 0 3.67-2.23 4.47-4.36 4.71.34.3.64.87.64 1.76v2.6c0 .25.17.55.66.46A9.5 9.5 0 0 0 12 2.5Z"
        , SP.fill_ "currentColor"
        , SP.fillRule_ "evenodd"
        , SP.clipRule_ "evenodd"
        ]
    ]
-----------------------------------------------------------------------------
mailIcon :: View context model action
mailIcon =
  S.svg_
    [ P.aria_ "hidden" "true"
    , P.xmlns_ "http://www.w3.org/2000/svg"
    , SP.fill_ "none"
    , SP.viewBox_ "0 0 24 24"
    , SP.stroke_ "currentColor"
    , SP.strokeWidth_ "1.75"
    , P.class_ "inline-block h-3 w-3 align-[-0.15em]"
    ]
    [ S.path_
        [ SP.d_ "m4 6.5 8 5.5 8-5.5M5 5h14a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z"
        , SP.strokeLinecap_ "round"
        , SP.strokeLinejoin_ "round"
        ]
    ]
-----------------------------------------------------------------------------
filledIcon :: [MisoString] -> MisoString -> View context model action
filledIcon paths className =
  S.svg_
    [ P.aria_ "hidden" "true"
    , P.class_ className
    , P.xmlns_ "http://www.w3.org/2000/svg"
    , SP.fill_ "none"
    , SP.viewBox_ "0 0 24 24"
    ]
    (map
      (\pathData -> S.path_
        [ SP.d_ pathData
        , SP.fill_ "currentColor"
        , SP.fillRule_ "evenodd"
        , SP.clipRule_ "evenodd"
        ])
      paths)
-----------------------------------------------------------------------------
outlinedIcon :: MisoString -> MisoString -> View context model action
outlinedIcon pathData className =
  S.svg_
    [ P.aria_ "hidden" "true"
    , P.class_ className
    , P.xmlns_ "http://www.w3.org/2000/svg"
    , SP.fill_ "none"
    , SP.viewBox_ "0 0 24 24"
    , SP.stroke_ "currentColor"
    , SP.strokeWidth_ "1.75"
    ]
    [ S.path_
        [ SP.d_ pathData
        , SP.strokeLinecap_ "round"
        , SP.strokeLinejoin_ "round"
        ]
    ]
-----------------------------------------------------------------------------
-- | The arrow that returns from a post to its section.
homeArrowIcon :: View context model action
homeArrowIcon = filledIcon
  [ "M9.70711 4.70711C10.0976 4.31658 10.0976 3.68342 9.70711 3.29289C9.31658 2.90237 8.68342 2.90237 8.29289 3.29289L3.29289 8.29289C2.90237 8.6833 2.90237 9.31658 3.29289 9.70711L8.29289 14.7071C8.68342 15.0976 9.31658 15.0976 9.70711 14.7071C10.0976 14.3166 10.0976 13.6834 9.70711 13.2929L6.41421 10H10.4C12.0967 10 13.309 10.0008 14.2594 10.0784C15.198 10.1551 15.7927 10.3018 16.27 10.545C17.2108 11.0243 17.9757 11.7892 18.455 12.73C18.6982 13.2073 18.8449 13.802 18.9216 14.7406C18.9992 15.691 19 16.9033 19 18.6V20C19 20.5523 19.4477 21 20 21C20.5523 21 21 20.5523 21 20V18.5556C21 16.913 21 15.6191 20.9149 14.5778C20.8281 13.5154 20.6478 12.6283 20.237 11.8221C19.5659 10.5049 18.4951 9.43407 17.1779 8.76295C16.3717 8.35217 15.4846 8.17186 14.4222 8.08507C13.3809 7.99999 12.087 7.99999 10.4444 8L6.41421 8L9.70711 4.70711Z"
  ] "post-action-icon"
-----------------------------------------------------------------------------
chainLinkIcon :: View context model action
chainLinkIcon = filledIcon
  [ "M6.46447 9.12169C8.4171 7.16907 11.5829 7.16907 13.5355 9.12169L13.8787 9.46484C14.695 10.2811 15.1709 11.3121 15.3042 12.3761C15.3729 12.9241 14.9843 13.424 14.4363 13.4926C13.8883 13.5613 13.3884 13.1727 13.3197 12.6247C13.2397 11.9862 12.9554 11.37 12.4645 10.8791L12.1213 10.5359C10.9498 9.36433 9.05026 9.36433 7.87869 10.5359L4.53554 13.8791C3.36397 15.0506 3.36397 16.9501 4.53554 18.1217L4.87869 18.4648C6.05026 19.6364 7.94976 19.6364 9.12133 18.4648L9.29287 18.2933C9.68338 17.9027 10.3165 17.9027 10.7071 18.2932C11.0976 18.6837 11.0976 19.3169 10.7071 19.7074L10.5356 19.879C8.58295 21.8316 5.41709 21.8317 3.46447 19.879L3.12133 19.5359C1.16871 17.5833 1.1687 14.4175 3.12133 12.4648L6.46447 9.12169Z"
  , "M13.4644 5.12169C15.417 3.16907 18.5829 3.16907 20.5355 5.12169L20.8786 5.46484C22.8313 7.41746 22.8313 10.5833 20.8786 12.5359L17.5355 15.8791C15.5829 17.8317 12.417 17.8317 10.4644 15.879L10.1213 15.5359C9.30499 14.7196 8.82903 13.6887 8.69574 12.6247C8.62709 12.0767 9.01569 11.5768 9.56369 11.5081C10.1117 11.4395 10.6116 11.8281 10.6802 12.3761C10.7602 13.0146 11.0445 13.6307 11.5355 14.1217L11.8786 14.4648C13.0502 15.6364 14.9497 15.6364 16.1213 14.4648L19.4644 11.1217C20.636 9.95012 20.636 8.05062 19.4644 6.87905L19.1213 6.53591C17.9497 5.36436 16.0503 5.36433 14.8787 6.53581L14.7072 6.70738C14.3167 7.09796 13.6836 7.09804 13.293 6.70757C12.9024 6.31709 12.9024 5.68393 13.2928 5.29335L13.4644 5.12169Z"
  ] "post-action-icon"
-----------------------------------------------------------------------------
checkIcon :: View context model action
checkIcon = outlinedIcon "m5 12.5 4.25 4.25L19 7" "post-action-icon"
-----------------------------------------------------------------------------
sunIcon :: View context model action
sunIcon =
  S.svg_
    [ SP.viewBox_ "0 0 24 24"
    , P.class_ "theme-icon"
    , P.aria_ "hidden" "true"
    , SP.fill_ "none"
    , SP.stroke_ "currentColor"
    , SP.strokeWidth_ "1.75"
    , SP.strokeLinecap_ "round"
    , SP.strokeLinejoin_ "round"
    ]
    [ S.circle_ [ SP.cx_ "12", SP.cy_ "12", SP.r_ "4" ]
    , S.path_ [ SP.d_ "M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" ]
    ]
-----------------------------------------------------------------------------
moonIcon :: View context model action
moonIcon =
  S.svg_
    [ SP.viewBox_ "0 0 24 24"
    , P.class_ "theme-icon"
    , P.aria_ "hidden" "true"
    , SP.fill_ "none"
    , SP.stroke_ "currentColor"
    , SP.strokeWidth_ "1.75"
    , SP.strokeLinecap_ "round"
    , SP.strokeLinejoin_ "round"
    ]
    [ S.path_ [ SP.d_ "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" ]
    ]
