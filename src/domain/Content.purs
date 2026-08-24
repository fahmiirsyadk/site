module Domain.Content where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as CodeUnits
import Data.String.Pattern (Pattern(..))

type Post =
  { title :: String
  , date :: String
  , slug :: String
  , section :: String
  , status :: String
  , excerpt :: String
  , banner :: String
  , ogTitle :: String
  , ogDescription :: String
  , ogImage :: String
  , html :: String
  }

type DocumentMetadata =
  { title :: String
  , description :: String
  , image :: String
  , contentType :: String
  }

type NeighboringPosts =
  { older :: Maybe Post
  , newer :: Maybe Post
  }

siteUrl :: String
siteUrl = "https://faah.me"

defaultDescription :: String
defaultDescription = "Notes on systems, software, and the long arc of building things that last."

defaultImage :: String
defaultImage = siteUrl <> "/assets/banners/pendulum.png"

defaultMetadata :: DocumentMetadata
defaultMetadata =
  { title: "Faah"
  , description: defaultDescription
  , image: defaultImage
  , contentType: "website"
  }

publishedPosts :: Array Post -> Array Post
publishedPosts source =
  source
    # Array.filter (\post -> post.status == "published")
    # Array.sortBy (\left right -> compare right.date left.date)

isSection :: String -> Boolean
isSection value = value == "thought" || value == "lab"

postsInSection :: Array Post -> String -> Array Post
postsInSection posts section = Array.filter (\post -> post.section == section) posts

findPost :: Array Post -> String -> String -> Maybe Post
findPost posts section slug =
  Array.find (\post -> post.section == section && post.slug == slug) posts

neighboringPosts :: Array Post -> Post -> NeighboringPosts
neighboringPosts posts post =
  let
    siblings = Array.sortBy (\left right -> compare left.date right.date) (postsInSection posts post.section)
    maybeIndex = Array.findIndex (\candidate -> candidate.slug == post.slug) siblings
  in
    case maybeIndex of
      Nothing -> { older: Nothing, newer: Nothing }
      Just index ->
        { older: if index > 0 then Array.index siblings (index - 1) else Nothing
        , newer: Array.index siblings (index + 1)
        }

metadataForPath :: Array Post -> String -> DocumentMetadata
metadataForPath posts path =
  case Array.filter (_ /= "") (String.split (Pattern "/") path) of
    [ section, slug ] ->
      if isSection section then metadataForPost (findPost posts section slug) else defaultMetadata
    _ -> defaultMetadata

metadataForPost :: Maybe Post -> DocumentMetadata
metadataForPost maybePost = case maybePost of
  Nothing -> defaultMetadata
  Just post -> metadataForPostValue post

metadataForPostValue :: Post -> DocumentMetadata
metadataForPostValue post =
  { title: fallback post.title post.ogTitle
  , description: fallback (fallback defaultDescription post.excerpt) post.ogDescription
  , image: absoluteImage (fallback "/assets/banners/pendulum.png" (fallback post.banner post.ogImage))
  , contentType: "article"
  }

absoluteImage :: String -> String
absoluteImage image =
  if CodeUnits.take 4 image == "http" then image else siteUrl <> image

fallback :: String -> String -> String
fallback defaultValue value = if value == "" then defaultValue else value
