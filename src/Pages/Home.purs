module Pages.Home where

import Prelude

import Components.PostPreview (postPreview)
import Types (Post)
import Data.Array as Array
import Luna.Html as H
import Luna.Html (Html)

view :: forall i. Array Post -> Html i
view posts =
  H.div [ H.classes [ "space-y-6" ] ]
    [ H.p [ H.classes [ "text-[12px]", "text-neutral-500" ] ] [ H.text "Latest posts" ]
    , if Array.null posts then
        H.p [ H.classes [ "text-[12px]", "text-neutral-500" ] ] [ H.text "No posts yet." ]
      else
        H.div [ H.classes [ "flex", "w-full", "flex-col" ] ] (map postPreview posts)
    ]
