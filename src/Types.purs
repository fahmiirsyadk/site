module Types where

import Prelude

import Data.Array as Array
import Data.Argonaut.Core (Json, fromObject, jsonEmptyObject)
import Data.Argonaut.Decode (class DecodeJson, JsonDecodeError(..), decodeJson, (.:), (.:?))
import Data.Argonaut.Encode (class EncodeJson, encodeJson, (:=), (~>))
import Data.Either (Either(..))
import Data.Maybe (Maybe, maybe)
import Foreign.Object as FO

-- | Structured markdown body segments (fenced cards + prose HTML). See `docs/content-blocks.md`.
data BodyBlock
  = BodyProseHtml String
  | BodyToolCard { id :: String, file :: String, addStat :: Maybe String, delStat :: Maybe String, content :: String }
  | BodyDiffCard { id :: String, file :: String, addStat :: Maybe String, delStat :: Maybe String, content :: String }
  | BodyTerminal { id :: String, title :: String, command :: String, output :: String }

derive instance eqBodyBlock :: Eq BodyBlock

insertMaybeStat :: String -> Maybe String -> FO.Object Json -> FO.Object Json
insertMaybeStat k mv o = maybe o (\v -> FO.insert k (encodeJson v) o) mv

instance encodeJsonBodyBlock :: EncodeJson BodyBlock where
  encodeJson = case _ of
    BodyProseHtml html ->
      "tag" := "prose" ~> "html" := html ~> jsonEmptyObject
    BodyToolCard r ->
      fromObject
        $ insertMaybeStat "delStat" r.delStat
        $ insertMaybeStat "addStat" r.addStat
        $ FO.insert "content" (encodeJson r.content)
        $ FO.insert "file" (encodeJson r.file)
        $ FO.insert "id" (encodeJson r.id)
        $ FO.insert "tag" (encodeJson "tool")
        $ FO.empty
    BodyDiffCard r ->
      fromObject
        $ insertMaybeStat "delStat" r.delStat
        $ insertMaybeStat "addStat" r.addStat
        $ FO.insert "content" (encodeJson r.content)
        $ FO.insert "file" (encodeJson r.file)
        $ FO.insert "id" (encodeJson r.id)
        $ FO.insert "tag" (encodeJson "diff")
        $ FO.empty
    BodyTerminal r ->
      "tag" := "terminal"
        ~> "id" := r.id
        ~> "title" := r.title
        ~> "command" := r.command
        ~> "output" := r.output
        ~> jsonEmptyObject

instance decodeJsonBodyBlock :: DecodeJson BodyBlock where
  decodeJson j = do
    o <- decodeJson j
    tag <- o .: "tag"
    case tag of
      "prose" -> BodyProseHtml <$> o .: "html"
      "tool" -> do
        id <- o .: "id"
        file <- o .: "file"
        addStat <- o .:? "addStat"
        delStat <- o .:? "delStat"
        content <- o .: "content"
        pure $ BodyToolCard { id, file, addStat, delStat, content }
      "diff" -> do
        id <- o .: "id"
        file <- o .: "file"
        addStat <- o .:? "addStat"
        delStat <- o .:? "delStat"
        content <- o .: "content"
        pure $ BodyDiffCard { id, file, addStat, delStat, content }
      "terminal" -> do
        id <- o .: "id"
        title <- o .: "title"
        command <- o .: "command"
        output <- o .: "output"
        pure $ BodyTerminal { id, title, command, output }
      _ -> Left (TypeMismatch "body block tag")

-- | Client state for Luna tool/diff display islands (`Components.ToolCard`, `Components.DiffCard`).
type ToolCardState =
  { expanded :: Boolean
  , needsExpand :: Boolean
  }

defaultToolCardState :: ToolCardState
defaultToolCardState =
  { expanded: true
  , needsExpand: true
  }

-- | `bodyHtml`: full article HTML when present (content build, per-post JSON, RSS-style feeds).
-- | Omitted or `null` in sliced / site-index payloads; the app uses `bodyBlocks` for rendering.
type Post =
  { slug :: String
  , title :: String
  , date :: String
  , description :: String
  , bodyHtml :: Maybe String
  , bodyBlocks :: Array BodyBlock
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