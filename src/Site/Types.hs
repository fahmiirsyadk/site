{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
module Site.Types
  ( Post(..)
  , PostSummary(..)
  , Section(..)
  , allSections
  , sectionLabel
  , sectionPath
  , calLabel
  , HeadInfo(..)
  ) where

import Data.Text (Text)
import Data.Aeson
import Data.Aeson ((.:), (.:?))
import qualified Data.Text as T
import Data.Foldable (toList)
import Data.Time.Calendar (Day)
import Data.Time.Format (parseTimeM, formatTime, defaultTimeLocale)

data Section = Articles | Projects | TIL deriving (Eq, Ord, Show)

allSections :: [Section]
allSections = [Articles, Projects, TIL]

sectionLabel :: Section -> Text
sectionLabel Articles = "articles"
sectionLabel Projects = "projects"
sectionLabel TIL      = "til"

sectionPath :: Section -> Text
sectionPath = ("/" <>) . sectionLabel

data Post = Post
  { pTitle        :: String
  , pDate         :: String
  , pSlug         :: String
  , pSection      :: String
  , pTags         :: [Text]
  , pExcerpt      :: Maybe String
  , pBanner       :: Maybe String
  , pOgTitle      :: Maybe String
  , pOgDescription:: Maybe String
  , pOgImage      :: Maybe String
  , pContent      :: String
  }

instance FromJSON Post where
  parseJSON = withObject "Post" $ \o -> do
    title <- o .:  "title"
    date  <- o .:  "date"
    slug  <- o .:? "slug" .!= ""
    tagsR <- o .:? "tags"
    let tags = case tagsR of Just (Array a) -> [s | String s <- toList a]; _ -> []
    exc   <- o .:? "excerpt"
    ban   <- o .:? "banner"
    ogt   <- o .:? "ogTitle"
    ogd   <- o .:? "ogDescription"
    ogi   <- o .:? "ogImage"
    content <- o .:  "content"
    pure Post
      { pTitle = title, pDate = date, pSlug = slug, pSection = ""
      , pTags = tags, pExcerpt = exc, pBanner = ban
      , pOgTitle = ogt, pOgDescription = ogd, pOgImage = ogi
      , pContent = content
      }

data PostSummary = PostSummary
  { psSlug    :: Text
  , psTitle   :: Text
  , psDate    :: Text
  , psRel     :: Text
  , psSection :: Text
  }

calLabel :: String -> Text
calLabel s = case (parseTimeM True defaultTimeLocale "%Y-%m-%d" (take 10 s) :: Maybe Day) of
  Just d  -> T.pack (formatTime defaultTimeLocale "%e %b %Y" (d :: Day))
  Nothing -> T.pack s

data HeadInfo = HeadInfo
  { hiTitle       :: Text
  , hiPath        :: Text
  , hiDescription :: Text
  , hiOgType      :: Text
  , hiOgImage     :: Text
  , hiTags        :: [Text]
  , hiPublished   :: Text
  }