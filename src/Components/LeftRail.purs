module Components.LeftRail where

import Prelude

import Components.Logo (cubeLogoLink)
import Routes (printRoutePath)
import Data.Maybe (Maybe(..))
import Types (Route(..), TocItem)
import Luna.Html as H
import Luna.Html (Html, attr)

leftRail :: forall i. Route -> Array TocItem -> Maybe String -> Maybe (String -> i) -> Html i
leftRail current toc activeTocId onTocSelect =
  H.aside
    [ H.classes
        [ "w-full"
        , "shrink-0"
        , "overflow-y-auto"
        , "border-t"
        , "border-[#E5E5E5]"
        , "bg-[#FAFAFA]"
        , "p-6"
        , "md:w-[300px]"
        , "md:min-h-0"
        , "md:h-full"
        , "md:border-t-0"
        , "md:border-r"
        ]
    ]
    [ H.div [ H.classes [ "flex", "min-h-full", "flex-col", "gap-7" ] ]
        [ H.div [] [ cubeLogoLink (printRoutePath Home) ]
        , if showToc then tocBlock toc activeTocId onTocSelect else defaultRail current
        ]
    ]
  where
  showToc = case current of
    Article _ -> true
    Project _ -> true
    _ -> false

tocBlock :: forall i. Array TocItem -> Maybe String -> Maybe (String -> i) -> Html i
tocBlock items activeId onSelect =
  H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
    [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "TOC" ]
    , H.div [ H.classes [ "space-y-0.5" ] ] (map (\item -> tocLink item activeId onSelect) items)
    ]

tocLink :: forall i. TocItem -> Maybe String -> Maybe (String -> i) -> Html i
tocLink item activeId onSelect =
  H.a
    ( [ H.href ("#" <> item.id)
      , attr "data-toc-id" item.id
      ]
        <> case onSelect of
            Nothing -> []
            Just mkAction -> [ H.onClick (H.always_ (mkAction item.id)) ]
        <>
          [ H.classes
              ( [ "block"
                , "underline"
                , "underline-offset-[3px]"
                , "transition-colors"
                , "duration-200"
                , "ease-out"
                ]
                  <> if activeId == Just item.id
                    then [ "text-[#FF4B26]", "decoration-[#FF4B26]" ]
                    else [ "decoration-neutral-300", "text-[#171717]", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]" ]
                  <> if item.level > 2 then [ "pl-3" ] else []
              )
          ]
    )
    [ H.text item.title ]

defaultRail :: forall i. Route -> Html i
defaultRail current =
  H.div [ H.classes [ "flex", "flex-col", "gap-7", "h-full" ] ]
    [ H.p [ H.classes [ "mb-1", "text-[12px]", "leading-[1.7]", "text-[#171717]" ] ]
        [ H.text "Notes, projects, and experiments in public" ]
    , H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
        [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "MENU" ]
        , navLink ProjectsIndex "projects" current
        , navLink ArticlesIndex "articles" current
        , navLink (Collection "til") "TIL" current
        ]
    , H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
        [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "LAB" ]
        , H.a [ H.href "https://of.domains", H.classes [ "underline", "underline-offset-[3px]", "decoration-neutral-300", "text-[#171717]", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]" ] ] [ H.text "of.domains" ]
        ]
    , H.div [ H.classes [ "mt-auto", "flex", "flex-col", "gap-1", "pb-1" ] ]
        [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "SOCIAL" ]
        , navLink About "about me" current
        ]
    ]

navLink :: forall i. Route -> String -> Route -> Html i
navLink route label current =
  H.a
    [ H.href (printRoutePath route)
    , H.classes
        $ [ "underline", "underline-offset-[3px]", "decoration-neutral-300", "text-[#171717]", "transition-colors", "duration-200", "ease-out", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]" ]
        <> if current == route then [ "text-[#FF4B26]", "decoration-[#FF4B26]" ] else []
    ]
    [ H.text label ]
