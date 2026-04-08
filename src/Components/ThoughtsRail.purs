module Components.ThoughtsRail where

import Prelude

import Types (Thought)
import Data.Array as Array
import Luna.Html as H
import Luna.Html (Html, unsafeRawHtml)

thoughtsRail :: forall i. Array Thought -> Html i
thoughtsRail thoughts =
  H.aside
    [ H.classes
        [ "h-[100svh]"
        , "overflow-y-auto"
        , "border-t"
        , "border-[#181818]"
        , "p-6"
        , "md:border-l"
        , "md:border-t-0"
        ]
    , H.id_ "col-thoughts"
    ]
    [ H.div [ H.classes [ "flex", "min-h-full", "flex-col", "gap-7" ] ]
        [ H.div [ H.classes [ "flex", "items-center", "justify-between", "gap-3" ] ]
            [ H.p [ H.classes [ "text-[36px]", "font-semibold", "leading-none", "text-[#b4b4b4]" ] ] [ H.text "PLAY" ]
            , H.p [ H.classes [ "text-[14px]", "text-[#404040]" ] ] [ H.text "█░░░░░░░░░░ 00:07" ]
            ]
        , if Array.null thoughts then
            H.p [ H.classes [ "text-[14px]", "text-[#404040]" ] ] [ H.text "No thoughts yet." ]
          else
            H.div [ H.classes [ "flex", "flex-col", "gap-8", "pb-4" ] ] (map thoughtItem thoughts)
        ]
    ]

thoughtItem :: forall i. Thought -> Html i
thoughtItem thought =
  H.article [ H.classes [ "mb-1" ] ]
    [ H.p [ H.classes [ "mb-2", "text-[12px]", "text-[#404040]" ] ] [ H.text thought.date ]
    , H.div [ H.classes [ "text-[40px]", "leading-[1.35]", "text-[#b4b4b4]" ] ] [ unsafeRawHtml thought.bodyHtml ]
    ]
