module BuildContent.MarkdownDoc
  ( FrontFields
  , ParsedDocument
  , RenderedBody
  , parseMarkdownDocument
  )
  where

import Prelude

import BodyBlockHtml (renderBodyBlock)
import BuildContent.MdHtml (renderDocument)
import Control.Alt ((<|>))
import Data.Argonaut.Core (Json, jsonEmptyObject, toArray, toObject)
import Data.Array as Array
import Data.Argonaut.Decode (decodeJson)
import Data.Either (Either(..), hush)
import Data.Traversable (traverse)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Data.String.Pattern (Pattern(..))
import Data.String.CodeUnits as CodeUnits
import Data.YAML.Foreign.Decode (parseYAMLToJson)
import Data.Foldable (foldMap)
import Effect (Effect)
import Effect.Exception (error, throwException)
import Control.Monad.Except (runExcept)
import Data.JSDate as JSD
import Foreign.Object as FO
import Types (BodyBlock, TocItem)

type FrontFields =
  { title :: Maybe String
  , slug :: Maybe String
  , date :: Maybe String
  , description :: Maybe String
  , excerpt :: Maybe String
  , banner :: Maybe String
  , tags :: Maybe (Array String)
  , status :: Maybe String
  , pinned :: Maybe Boolean
  , ogTitle :: Maybe String
  , ogDescription :: Maybe String
  , ogImage :: Maybe String
  }

type RenderedBody =
  { bodyHtml :: String
  , bodyBlocks :: Array BodyBlock
  , toc :: Array TocItem
  }

type ParsedDocument =
  { fields :: FrontFields
  , dateIso :: String
  , rendered :: RenderedBody
  }

splitFrontMatter :: String -> { yaml :: String, body :: String }
splitFrontMatter src =
  let
    trimmed = String.trim src
  in
    if String.take 3 trimmed /= "---" then
      { yaml: "", body: src }
    else
      let
        rest = String.drop 3 trimmed
        afterFirstNl = fromMaybe rest $ String.stripPrefix (Pattern "\n") rest
      in
        case String.indexOf (Pattern "\n---") afterFirstNl of
          Nothing ->
            { yaml: "", body: src }
          Just idx ->
            let
              yamlBlock = String.take idx afterFirstNl
              afterSep = String.drop (idx + 4) afterFirstNl
              body = fromMaybe afterSep $ String.stripPrefix (Pattern "\n") afterSep
            in
              { yaml: yamlBlock, body }

readJsonString :: Json -> Maybe String
readJsonString j = hush (decodeJson j)

readJsonStringArray :: Json -> Maybe (Array String)
readJsonStringArray j =
  case toArray j of
    Just arr ->
      traverse (\x -> hush (decodeJson x :: Either _ String)) arr
    Nothing ->
      Nothing

readDateAsString :: Json -> Maybe String
readDateAsString j =
  case readJsonString j of
    Just s -> Just s
    Nothing -> (hush (decodeJson j) :: Maybe Number) <#> show

parseFrontFields :: Json -> FrontFields
parseFrontFields j =
  case toObject j of
    Nothing ->
      { title: Nothing
      , slug: Nothing
      , date: Nothing
      , description: Nothing
      , excerpt: Nothing
      , banner: Nothing
      , tags: Nothing
      , status: Nothing
      , pinned: Nothing
      , ogTitle: Nothing
      , ogDescription: Nothing
      , ogImage: Nothing
      }
    Just o ->
      let
        lk k = FO.lookup k o
      in
        { title: lk "title" >>= readJsonString
        , slug: lk "slug" >>= readJsonString
        , date: lk "date" >>= readDateAsString
        , description: lk "description" >>= readJsonString
        , excerpt: lk "excerpt" >>= readJsonString
        , banner: lk "banner" >>= readJsonString
        , tags: lk "tags" >>= readJsonStringArray
        , status: lk "status" >>= readJsonString
        , pinned: lk "pinned" >>= hush <<< decodeJson
        , ogTitle: lk "ogTitle" >>= readJsonString
        , ogDescription: lk "ogDescription" >>= readJsonString
        , ogImage: lk "ogImage" >>= readJsonString
        }

yamlToFrontFields :: String -> FrontFields
yamlToFrontFields yamlStr =
  let
    parsed =
      if String.length (String.trim yamlStr) == 0 then
        parseFrontFields jsonEmptyObject
      else
        case runExcept $ parseYAMLToJson yamlStr of
          Left _ ->
            parseFrontFields jsonEmptyObject
          Right j ->
            parseFrontFields j
  in
    parsed { date = parsed.date <|> extractDateFromYamlText yamlStr }

extractDateFromYamlText :: String -> Maybe String
extractDateFromYamlText yamlStr =
  let
    lines = String.split (Pattern "\n") yamlStr
    extract ln =
      case String.stripPrefix (Pattern "date:") (String.trim ln) of
        Nothing -> Nothing
        Just raw ->
          let
            s0 = String.trim raw
            s1 = stripSurroundingQuotes s0
          in
            if String.length s1 == 0 then Nothing else Just s1
  in
    Array.head (Array.mapMaybe extract lines)

stripSurroundingQuotes :: String -> String
stripSurroundingQuotes s =
  let
    len = String.length s
  in
    if len >= 2 then
      let
        first = CodeUnits.take 1 s
        last = CodeUnits.drop (len - 1) s
      in
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") then
          CodeUnits.drop 1 (CodeUnits.take (len - 1) s)
        else
          s
    else
      s

epochIso :: String
epochIso = "1970-01-01T00:00:00.000Z"

normalizeDateToIso :: Maybe String -> Effect String
normalizeDateToIso Nothing = pure epochIso
normalizeDateToIso (Just s) = do
  d <- JSD.parse s
  if JSD.isValid d then JSD.toISOString d else pure epochIso

parseMarkdownDocument :: String -> Effect ParsedDocument
parseMarkdownDocument src = do
  let
    { yaml, body } = splitFrontMatter src
    fields = yamlToFrontFields yaml
    doc = renderDocument body
    bodyHtml = doc.html
    bodyBlocks = doc.blocks
    toc = doc.toc
  unless (bodyHtml == foldMap renderBodyBlock bodyBlocks) do
    let slugHint = fromMaybe "unknown" fields.slug
    throwException $ error ("MdHtml parity: bodyHtml /= foldMap renderBodyBlock bodyBlocks (slug: " <> slugHint <> ")")
  dateIso <- normalizeDateToIso fields.date
  pure
    { fields
    , dateIso
    , rendered: { bodyHtml, bodyBlocks, toc }
    }
