module Page.Section where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Foldkit.Html as HH
import Foldkit.Html.Prop as HP

type Post =
  { slug :: String
  , title :: String
  , path :: String
  , date :: String
  , dateLabel :: String
  }

type Input =
  { section :: String
  , posts :: Array Post
  }

postPreview :: forall message. Post -> HH.Child message
postPreview post =
  HH.keyed "div" post.slug
    [ HP.class_ "flex w-full items-center gap-3 py-2 text-[12px] leading-[1.7]" ]
    [ HH.a
        [ HP.href post.path
        , HP.class_ "shrink-0 font-instrument text-[16px] leading-[1.3] text-[#171717] no-underline hover:text-[#FF4B26] dark:text-neutral-200 dark:hover:text-[#FF6B4A]"
        ]
        [ HH.text post.title ]
    , HH.span [ HP.class_ "min-h-px min-w-6 flex-1 border-b border-neutral-300 dark:border-neutral-600" ] []
    , HH.span
        [ HP.dataAttribute "relative-date" post.date
        , HP.class_ "shrink-0 whitespace-nowrap text-right text-neutral-500"
        ]
        [ HH.text post.dateLabel ]
    ]

view :: forall message. Input -> HH.Child message
view input =
  HH.div [ HP.class_ "space-y-6" ]
    [ HH.h1 [ HP.class_ "text-[12px] font-semibold leading-[1.7] text-[#171717] dark:text-neutral-100" ]
        [ HH.text input.section ]
    , case Array.uncons input.posts of
        Nothing -> HH.p [ HP.class_ "text-[12px] text-neutral-500" ] [ HH.text "Nothing here yet." ]
        Just _ -> HH.div [ HP.class_ "flex w-full flex-col" ] (map postPreview input.posts)
    ]
