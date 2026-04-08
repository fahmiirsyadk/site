module Pages.Project where

import Prelude

import Types (Post)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import RelativeTime (relativeTimeLabel)
import Luna.Html as H
import Luna.Html (Html, unsafeRawHtml)

view :: forall i. String -> Array Post -> Html i
view slug posts =
  case Array.find (\p -> p.slug == slug && p.section == "projects") posts of
    Nothing ->
      H.div [ H.classes [ "space-y-3" ] ]
        [ H.h1 [ H.classes [ "text-[12px]", "leading-[1.7]", "font-semibold", "text-[#171717]" ] ] [ H.text "Project not found" ] ]
    Just p ->
      H.article [ H.classes [ "space-y-6" ] ]
        [ H.div
            [ H.classes [ "flex", "w-full", "items-end", "gap-3", "text-[12px]", "leading-[1.7]" ] ]
            [ H.h1 [ H.classes [ "shrink-0", "font-medium", "text-[#171717]" ] ] [ H.text p.title ]
            , H.span
                [ H.classes [ "mb-[5px]", "min-h-px", "min-w-[1.5rem]", "flex-1", "border-b", "border-dotted", "border-neutral-300" ] ]
                []
            , H.span [ H.classes [ "shrink-0", "text-right", "text-neutral-500" ] ] [ H.text (relativeTimeLabel p.date) ]
            ]
        , H.div
            [ H.classes
                [ "prose"
                , "prose-neutral"
                , "max-w-none"
                , "prose-sm"
                , "prose-headings:text-[#171717]"
                , "prose-p:text-neutral-700"
                 , "prose-li:text-neutral-700"
                , "prose-ul:list-none"
                , "prose-ol:list-none"
                , "prose-ul:pl-0"
                , "prose-ol:pl-0"
                , "prose-strong:text-[#171717]"
                , "prose-a:text-[#FF4B26]"
                , "prose-a:decoration-[#FF4B26]/40"
                ]
            ]
            [ unsafeRawHtml p.bodyHtml ]
        ]