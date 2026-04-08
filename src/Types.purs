module Types where

import Prelude

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
  , articles :: Array Post
  , projects :: Array Post
  }

emptySiteManifest :: SiteManifest
emptySiteManifest =
  { posts: []
  , thoughts: []
  , tags: []
  , articles: []
  , projects: []
  }

data Route
  = Home
  | Article String
  | Project String
  | Collection String
  | About
  | ArticlesIndex
  | ProjectsIndex

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