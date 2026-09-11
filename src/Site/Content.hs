-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | Pure queries over the generated post catalog.
--
-- The semantics mirror the source site: published posts are ordered newest
-- first, drafts never surface, and neighbouring posts walk a section in
-- chronological order. Nothing here touches IO, so the browser and the
-- prerenderer ask the same questions of the same data.
module Site.Content
  ( -- * Types
    Post (..)
  , TocEntry (..)
    -- * Queries
  , posts
  , publishedPosts
  , postsInSection
  , findPost
  , neighboringPosts
  ) where
-----------------------------------------------------------------------------
import           Data.Function (on)
import           Data.List (elemIndex, find, sortBy)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import qualified Site.Content.Generated as Generated
import           Site.Content.Types (Post (..), TocEntry (..), PublicationStatus (..))
import           Site.Section (Section)
-----------------------------------------------------------------------------
-- | Every post in the repository, drafts included.
posts :: [Post]
posts = Generated.posts
-----------------------------------------------------------------------------
-- | Published posts, newest first.
publishedPosts :: [Post]
publishedPosts =
   sortBy (flip compare `on` postDate) (filter ((== Published) . postStatus) posts)
-----------------------------------------------------------------------------
postsInSection :: Section -> [Post]
postsInSection section =
  filter ((== section) . postSection) publishedPosts
-----------------------------------------------------------------------------
findPost :: Section -> MisoString -> Maybe Post
findPost section slug =
  find (\post -> postSection post == section && postSlug post == slug) publishedPosts
-----------------------------------------------------------------------------
-- | The older and newer posts in the same section. Chronological order, so
-- @older@ comes before the post and @newer@ after it.
neighboringPosts :: Post -> (Maybe Post, Maybe Post)
neighboringPosts post =
  case elemIndex (postSlug post) (map postSlug siblings) of
    Nothing -> (Nothing, Nothing)
    Just index ->
      ( indexMaybe (index - 1)
      , indexMaybe (index + 1)
      )
  where
    siblings = sortBy (compare `on` postDate) (postsInSection (postSection post))
    indexMaybe index = if index < 0 then Nothing else lookupAt siblings index

lookupAt :: [a] -> Int -> Maybe a
lookupAt values index =
  case drop index values of
    (value : _) -> Just value
    []          -> Nothing
