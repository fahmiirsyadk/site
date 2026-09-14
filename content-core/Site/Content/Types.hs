{-# LANGUAGE OverloadedStrings #-}

-- | The content record emitted by the native compiler.
module Site.Content.Types
  ( Post (..)
  , TocEntry (..)
  , PublicationStatus (..)
  ) where

import Data.Text (Text)
import Site.Prose.Types (Block)
import Site.Section (Section)

data PublicationStatus = Draft | Published
  deriving (Show, Eq)

data TocEntry = TocEntry
  { tocId :: Text
  , tocLabel :: Text
  , tocLevel :: Int
  } deriving (Show, Eq)

data Post = Post
  { postTitle :: Text
  , postDate :: Text
  , postDateLabel :: Text
  , postSlug :: Text
  , postSection :: Section
  , postStatus :: PublicationStatus
  , postTags :: [Text]
  , postExcerpt :: Text
  , postBanner :: Text
  , postOgTitle :: Text
  , postOgDescription :: Text
  , postOgImage :: Text
  , postBody :: [Block]
  , postToc :: [TocEntry]
  } deriving (Show, Eq)
