module Components.Footer where

import Luna.Html as H
import Luna.Html (Html, attr)

footer :: forall i. Html i
footer =
  H.div
    [ H.classes
        [ "flex"
        , "w-full"
        , "min-h-0"
        , "flex-1"
        , "flex-col"
        , "self-stretch"
        , "mt-10"
        ]
    ]
    [ H.div
        [ H.id_ "sea-footer"
        , H.classes
            [ "relative"
            , "flex"
            , "min-h-0"
            , "w-full"
            , "flex-1"
            , "overflow-hidden"
            , "rounded-lg"
            , "bg-transparent"
            , "dark:bg-[#171717]"
            ]
        , attr "style" "min-height:clamp(240px,34vh,420px);width:calc(100% + 4rem);margin-left:-2rem;margin-right:-2rem;"
        ]
        [ H.canvas
            [ H.id_ "sea-canvas"
            , attr "aria-label" "Sea animation"
            , H.classes [ "block", "w-full", "bg-transparent" ]
            ]
        , H.div
            [ H.classes
                [ "pointer-events-none"
                , "absolute"
                , "bottom-4"
                , "left-4"
                , "right-4"
                , "z-10"
                , "flex"
                , "justify-start"
                ]
            ]
            [ H.span
                [ H.classes
                    [ "pointer-events-auto"
                    , "inline-flex"
                    , "rounded-full"
                    , "border"
                    , "border-[#E5E5E5]"
                    , "bg-white"
                    , "dark:border-neutral-700"
                    , "dark:bg-neutral-900"
                    , "dark:text-neutral-300"
                    , "px-3"
                    , "py-1.5"
                    , "text-[12px]"
                    , "leading-none"
                    , "text-neutral-500"
                    , "shadow-sm"
                    ]
                ]
                [ H.text "Built with Luna · design pass v1" ]
            ]
        ]
    ]
