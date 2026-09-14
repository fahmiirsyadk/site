{-# LANGUAGE OverloadedStrings #-}

module Site.Content.Compiler.Frontmatter
  ( compilePost
  ) where

import Data.Aeson (FromJSON (..), (.:), (.:?), (.!=), withObject)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (ZonedTime, defaultTimeLocale, formatTime, parseTimeM)
import Data.Yaml (decodeEither')
import System.FilePath (dropExtension, takeFileName)
import Site.Content.Compiler.Markdown (ParsedDocument (..), parseMarkdown)
import qualified Site.Content.Compiler.Markdown as Markdown
import Site.Content.Types (Post (..), PublicationStatus (..), TocEntry (..))
import Site.Section (parseSection)

data Frontmatter = Frontmatter
  { frontTitle :: T.Text
  , frontDate :: T.Text
  , frontSlug :: Maybe T.Text
  , frontSection :: T.Text
  , frontStatus :: T.Text
  , frontTags :: [T.Text]
  , frontExcerpt :: T.Text
  , frontBanner :: T.Text
  , frontOgTitle :: T.Text
  , frontOgDescription :: T.Text
  , frontOgImage :: T.Text
  }

instance FromJSON Frontmatter where
  parseJSON = withObject "frontmatter" $ \object -> Frontmatter
    <$> object .: "title"
    <*> object .:? "date" .!= ""
    <*> object .:? "slug"
    <*> object .:? "section" .!= "thought"
    <*> object .:? "status" .!= "draft"
    <*> object .:? "tags" .!= []
    <*> object .:? "excerpt" .!= ""
    <*> object .:? "banner" .!= ""
    <*> object .:? "ogTitle" .!= ""
    <*> object .:? "ogDescription" .!= ""
    <*> object .:? "ogImage" .!= ""

compilePost :: FilePath -> T.Text -> Either String Post
compilePost path source = do
  (metadata, body) <- splitFrontmatter path source
  front <- either (Left . show) Right (decodeEither' (TE.encodeUtf8 metadata))
  section <- maybe (Left (path <> ": unknown section " <> T.unpack (frontSection front))) Right
    (parseSection (frontSection front))
  status <- parseStatus path (frontStatus front)
  document <- parseMarkdown path body
  dateLabel <- dateLabelFor path (frontDate front)
  pure Post
    { postTitle = frontTitle front
    , postDate = frontDate front
    , postDateLabel = dateLabel
    , postSlug = maybe (fallbackSlug path) id (frontSlug front)
    , postSection = section
    , postStatus = status
    , postTags = frontTags front
    , postExcerpt = frontExcerpt front
    , postBanner = frontBanner front
    , postOgTitle = frontOgTitle front
    , postOgDescription = frontOgDescription front
    , postOgImage = frontOgImage front
    , postBody = parsedBlocks document
    , postToc = map tocEntry (parsedToc document)
    }
  where
    tocEntry entry = TocEntry
      (Markdown.tocId entry)
      (Markdown.tocLabel entry)
      (Markdown.tocLevel entry)

splitFrontmatter :: FilePath -> T.Text -> Either String (T.Text, T.Text)
splitFrontmatter path source = case T.lines source of
  (first : rest) | first == "---" ->
    case break (== "---") rest of
      (header, _ : body) -> Right (T.unlines header, T.unlines body)
      _ -> Left (path <> ": unterminated frontmatter")
  _ -> Left (path <> ": frontmatter must start with ---")

parseStatus :: FilePath -> T.Text -> Either String PublicationStatus
parseStatus _ "published" = Right Published
parseStatus _ "draft" = Right Draft
parseStatus path value = Left (path <> ": unknown status " <> T.unpack value)

dateLabelFor :: FilePath -> T.Text -> Either String T.Text
dateLabelFor _ "" = Right ""
dateLabelFor path value = case (parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%S%z" (T.unpack value) :: Maybe ZonedTime) of
  Nothing -> Left (path <> ": invalid date " <> T.unpack value)
  Just date -> Right (T.pack (formatTime defaultTimeLocale "%b %-d, %Y" date))

fallbackSlug :: FilePath -> T.Text
fallbackSlug = T.pack . dropExtension . takeFileName
