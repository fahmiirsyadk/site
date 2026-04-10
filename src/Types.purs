module Types where

import Prelude

import Data.Array as Array
import Data.Generic.Rep (class Generic)
import Data.Show.Generic (genericShow)

type Post =
  { slug :: String
  , title :: String
  , date :: String
  , description :: String
  , bodyHtml :: String
  , toc :: Array TocItem
  , section :: String
  , tags :: Array String
  , excerpt :: String
  , banner :: String
  }

type TocItem =
  { id :: String
  , title :: String
  , level :: Int
  }

type Thought =
  { slug :: String
  , title :: String
  , date :: String
  , status :: String
  , pinned :: Boolean
  , bodyHtml :: String
  , excerpt :: String
  }

type SiteManifest =
  { posts :: Array Post
  , thoughts :: Array Thought
  , tags :: Array String
  }

articlesFromManifest :: SiteManifest -> Array Post
articlesFromManifest = Array.filter (_.section >>> (==) "articles") <<< _.posts

projectsFromManifest :: SiteManifest -> Array Post
projectsFromManifest = Array.filter (_.section >>> (==) "projects") <<< _.posts

tilFromManifest :: SiteManifest -> Array Post
tilFromManifest = Array.filter (_.section >>> (==) "til") <<< _.posts

emptySiteManifest :: SiteManifest
emptySiteManifest =
  { posts: []
  , thoughts: []
  , tags: []
  }

data Route
  = Home
  | About
  | SectionIndex String
  | SectionPost String String

derive instance eqRoute :: Eq Route
derive instance genericRoute :: Generic Route _

instance showRoute :: Show Route where
  show = genericShow

type LikeModel = { likes :: Int }

initialLikes :: LikeModel
initialLikes = { likes: 0 }

type SearchModel = 
  { query :: String
  , posts :: Array Post
  }

initialSearchModel :: SearchModel
initialSearchModel = { query: "", posts: [] }