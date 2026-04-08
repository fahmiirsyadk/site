module Pages.Collection where

import Prelude

import Components.PostPreview (postPreview)
import Types (Post)
import Data.Array as Array
import Luna.Html as H
import Luna.Html (Html)

view :: forall i. String -> Array Post -> Html i
view tag posts =
  let 
    taggedPosts = Array.filter (\p -> Array.elem tag p.tags) posts
  in
    H.div [ H.classes [ "space-y-6" ] ]
      [ H.p [ H.classes [ "text-[12px]", "text-neutral-500" ] ] [ H.text $ "Collection · " <> tag ]
      , if Array.null taggedPosts then
          H.p [ H.classes [ "text-[12px]", "text-neutral-500" ] ] [ H.text "No posts in this collection." ]
        else
          H.div [ H.classes [ "flex", "w-full", "flex-col" ] ]
            (map postPreview taggedPosts)
      ]