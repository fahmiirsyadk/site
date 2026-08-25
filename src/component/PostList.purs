module Component.PostList where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Foldkit.Html as HH
import Foldkit.Html.Prop as HP

type Input item message =
  { posts :: Array item
  , emptyLabel :: String
  , emptyText :: String
  , render :: item -> HH.Child message
  }

view :: forall item message. Input item message -> HH.Child message
view input =
  HH.section [ HP.class_ "space-y-6" ]
    [ HH.p [ HP.class_ "text-[12px] text-neutral-500" ] [ HH.text input.emptyLabel ]
    , case Array.uncons input.posts of
        Nothing -> HH.p [ HP.class_ "text-[12px] text-neutral-500" ] [ HH.text input.emptyText ]
        Just _ -> HH.div [ HP.class_ "flex w-full flex-col" ] (map input.render input.posts)
    ]
