module Components.SearchIsland where

import Prelude

import Types (Post, SearchModel, initialSearchModel)
import Luna.Html as H
import Luna.Html (Html)
import Luna.PureApp (PureApp)

data Action
  = UpdateQuery String

update :: SearchModel -> Action -> SearchModel
update model = case _ of
  UpdateQuery q -> model { query = q }

render :: SearchModel -> Html Action
render model =
  H.div [ H.classes [ "search-island", "p-4", "border", "border-zinc-800", "rounded" ] ]
    [ H.input 
        [ H.classes [ "w-full", "p-2", "bg-zinc-900", "border", "border-zinc-700", "rounded", "text-zinc-100" ]
        , H.placeholder "Search posts..."
        , H.value model.query
        , H.onValueInput (H.always UpdateQuery)
        ]
    , H.div [ H.classes [ "mt-4", "space-y-2" ] ]
        (map renderPostItem filteredPosts)
    ]
  where
  filteredPosts = if model.query == "" then [] else model.posts
  renderPostItem :: Post -> Html Action
  renderPostItem p =
    H.div [ H.classes [ "p-2", "hover:bg-zinc-800", "rounded" ] ]
      [ H.a 
          [ H.href ("/articles/" <> p.slug <> "/")
          , H.classes [ "text-white", "hover:underline" ]
          ]
          [ H.text p.title ]
      ]

app :: PureApp SearchModel Action
app =
  { render
  , update
  , init: initialSearchModel
  }

initialPosts :: Array Post -> SearchModel
initialPosts posts = initialSearchModel { posts = posts }