module Components.PostPreview where

import Routes (printRoutePath)
import RelativeTime (relativeTimeLabel)
import Types (Post, Route(..))
import Luna.Html as H
import Luna.Html (Html)

postPreview :: forall i. Post -> Html i
postPreview p =
  let
    route = SectionPost p.section p.slug
  in
  H.div
    [ H.classes [ "flex", "w-full", "items-end", "gap-3", "py-2", "text-[12px]", "leading-[1.7]" ] ]
    [ H.a
        [ H.href (printRoutePath route)
        , H.classes [ "shrink-0", "font-medium", "text-[#171717]", "no-underline", "hover:text-[#FF4B26]" ]
        ]
        [ H.text p.title ]
    , H.span
        [ H.classes [ "mb-[5px]", "min-h-px", "min-w-[1.5rem]", "flex-1", "border-b", "border-dotted", "border-neutral-300" ] ]
        []
    , H.span
        [ H.classes [ "shrink-0", "whitespace-nowrap", "text-right", "text-neutral-500" ] ]
        [ H.text (relativeTimeLabel p.date) ]
    ]
