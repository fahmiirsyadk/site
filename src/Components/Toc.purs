module Components.Toc
  ( tocBlock
  , tocLink
  , showTocSidebar
  ) where

import Prelude

import Data.Array (null)
import Data.Maybe (Maybe(..))
import Luna.Html (Html, attr)
import Luna.Html as H
import Types (Route(..), TocItem)

-- | Desktop TOC sidebar (and TOC in the mobile drawer) only for long-form sections that ship headings.
tocSidebarSection :: String -> Boolean
tocSidebarSection s = s == "articles" || s == "collection"

-- | Show the aside / TOC rail when this post has outline headings to navigate.
showTocSidebar :: Route -> Array TocItem -> Boolean
showTocSidebar (SectionPost section _) toc = tocSidebarSection section && not (null toc)
showTocSidebar _ _ = false

tocBlock :: forall i. Array TocItem -> Maybe String -> Html i
tocBlock items activeId =
  H.div [ H.classes [ "flex", "flex-col", "gap-1" ] ]
    [ H.p [ H.classes [ "mb-1", "text-[10px]", "font-medium", "uppercase", "tracking-[0.07em]", "text-neutral-500" ] ] [ H.text "TOC" ]
    , H.div [ H.classes [ "space-y-0.5" ] ] (map (\item -> tocLink item activeId) items)
    ]

tocLink :: forall i. TocItem -> Maybe String -> Html i
tocLink item activeId =
  H.a
    ( [ H.href ("#" <> item.id)
      , attr "data-toc-id" item.id
      ]
        <>
          [ H.classes
              ( [ "block"
                , "transition-colors"
                , "duration-200"
                , "ease-out"
                ]
                  <> if activeId == Just item.id
                    then [ "text-[#FF4B26]", "decoration-[#FF4B26]" ]
                    else [ "decoration-neutral-300", "text-[#171717]", "hover:text-[#FF4B26]", "hover:decoration-[#FF4B26]", "dark:text-neutral-200", "dark:hover:text-[#FF6B4A]" ]
                  <> if item.level > 2 then [ "pl-3" ] else []
              )
          ]
    )
    [ H.text ("- " <> item.title) ]
