module Components.PostPreview where

import Routes (printRoutePath)
import RelativeTime (postDateLabel)
import Types (Post, Route(..))
import Luna.Html as H
import Luna.Html (Html)

postPreview :: forall i. Post -> Html i
postPreview p =
  let
    route = SectionPost p.section p.slug
  in
  H.div
    [ H.classes [ "flex", "w-full", "items-center", "gap-3", "py-2", "text-normal", "leading-[1.7]" ] ]
    [ H.a
        [ H.href (printRoutePath route)
        , H.classes [ "shrink-0", "font-instrument", "text-[16px]", "leading-[1.3]", "text-[#171717]", "no-underline", "hover:text-[#FF4B26]", "dark:text-neutral-200", "dark:hover:text-[#FF6B4A]" ]
        ]
        [ H.text p.title ]
    , H.span
        [ H.classes [ "min-h-px", "min-w-[1.5rem]", "flex-1", "border-b", "border-solid", "border-neutral-300", "dark:border-neutral-600" ] ]
        []
    , H.span
        [ H.classes [ "shrink-0", "whitespace-nowrap", "text-right", "text-neutral-500" ]
        , H.attr "data-relative-date" p.date
        ]
        [ H.text (postDateLabel p.date) ]
    ]
