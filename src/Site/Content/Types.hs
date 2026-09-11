-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The shape of a post. The generated module 'Site.Content.Generated' fills
-- these records from @content/*.md@; 'Site.Content' queries them.
--
-- Field values mirror the source site: absent frontmatter is @""@ rather than
-- 'Nothing', because the query layer applies the same fallbacks the source
-- did, and the record stays flat enough to emit as a literal.
module Site.Content.Types
  ( Post (..)
   , TocEntry (..)
   , PublicationStatus (..)
  ) where
-----------------------------------------------------------------------------
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.Prose (Block)
import           Site.Section (Section)

data PublicationStatus = Draft | Published
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data TocEntry = TocEntry
  { tocId    :: MisoString
  , tocLabel :: MisoString
  , tocLevel :: Int
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data Post = Post
  { postTitle         :: MisoString
  , postDate          :: MisoString
  -- ^ ISO instant, used for sorting and the @data-relative-date@ attribute.
  , postDateLabel     :: MisoString
  -- ^ Precomputed display date, so native and WASM agree without @Intl@.
  , postSlug          :: MisoString
   , postSection       :: Section
   , postStatus        :: PublicationStatus
  , postTags          :: [MisoString]
  , postExcerpt       :: MisoString
  , postBanner        :: MisoString
  , postOgTitle       :: MisoString
  , postOgDescription :: MisoString
  , postOgImage       :: MisoString
  , postBody          :: [Block]
  , postToc           :: [TocEntry]
  } deriving (Show, Eq)
