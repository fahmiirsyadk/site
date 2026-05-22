module BuildContent.MdHtml
  ( renderDocument
  ) where

import Prelude

import BodyBlockHtml as BBH
import BuildContent.MarkdownParse (parse)
import BuildContent.Slugify (slugify)
import Data.Array as Array
import Data.Enum (fromEnum)
import Data.Foldable (all, foldMap)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Data.String.CodeUnits as CU
import MarkdownIt (MdToken(..), MdAttr)
import Types (BodyBlock(..))

type TocRow =
  { id :: String
  , title :: String
  , level :: Int
  }

escapeHtml :: String -> String
escapeHtml =
  String.replaceAll (String.Pattern "&") (String.Replacement "&amp;")
    >>> String.replaceAll (String.Pattern "<") (String.Replacement "&lt;")
    >>> String.replaceAll (String.Pattern ">") (String.Replacement "&gt;")
    >>> String.replaceAll (String.Pattern "\"") (String.Replacement "&quot;")
    >>> String.replaceAll (String.Pattern "'") (String.Replacement "&#39;")

escapeAttr :: String -> String
escapeAttr = escapeHtml

renderAttrs :: Array MdAttr -> String
renderAttrs = foldMap \a -> " " <> a.key <> "=\"" <> escapeAttr a.value <> "\""

collectInlineText :: MdToken -> String
collectInlineText (MdToken t) =
  case t.type of
    "text" -> t.content
    "code_inline" -> t.content
    "image" -> fromMaybe "" $ Array.find (\a -> a.key == "alt") t.attrs <#> _.value
    "softbreak" -> " "
    "hardbreak" -> " "
    _ -> foldMap collectInlineText t.children

shouldSkipTocHeading :: String -> String -> Boolean
shouldSkipTocHeading title id =
  let n = String.toLower $ String.trim title
  in n == "" || n == "table of contents" || n == "toc" || String.take 17 id == "table-of-contents"

renderInlineTok :: MdToken -> String
renderInlineTok (MdToken t)
  | t.hidden = ""
  | otherwise = case t.type of
      "text" -> escapeHtml t.content
      "html_inline" -> t.content -- consider disabling html:true in parser for safety
      "softbreak" -> "\n"
      "hardbreak" -> "<br />\n"
      "link_open" -> "<a" <> renderAttrs t.attrs <> ">"
      "link_close" -> "</a>"
      "image" -> "<img" <> renderAttrs t.attrs <> " />"
      "code_inline" -> "<code>" <> escapeHtml t.content <> "</code>"
      _ ->
        if t.nesting == 1 && t.tag /= "" then
          "<" <> t.tag <> renderAttrs t.attrs <> ">"
        else if t.nesting == -1 && t.tag /= "" then
          "</" <> t.tag <> ">"
        else ""

renderInlineChildren :: Array MdToken -> String
renderInlineChildren = foldMap renderInlineTok

renderInline :: MdToken -> String
renderInline (MdToken t) =
  if t.type == "inline" then renderInlineChildren t.children
  else renderInlineTok (MdToken t)

toolDisplayCardPrefix :: String
toolDisplayCardPrefix = "tool-display-card"

diffFencePrefix :: String
diffFencePrefix = "diff"

terminalFencePrefix :: String
terminalFencePrefix = "terminal"

infoWords :: String -> Array String
infoWords s =
  Array.filter (\w -> String.length (String.trim w) > 0)
    $ map String.trim
    $ String.split (String.Pattern " ") s

digitsOnly :: String -> Boolean
digitsOnly str =
  all (\c -> c >= '0' && c <= '9') (CU.toCharArray str)

-- | Matches `+12` or `-3` style diff stats.
matchSignedStat :: String -> Maybe String
matchSignedStat raw =
  let
    s = String.trim raw
  in
    if String.length s < 2 then Nothing
    else
      let
        sign = CU.take 1 s
        rest = CU.drop 1 s
      in
        if (sign == "+" || sign == "-") && digitsOnly rest then Just s else Nothing

type ToolDisplayMeta =
  { file :: String
  , addStat :: Maybe String
  , delStat :: Maybe String
  }

parseFileAndStats :: Array String -> ToolDisplayMeta
parseFileAndStats parts =
  let
    n = Array.length parts
  in
    if n == 0 then { file: "snippet", addStat: Nothing, delStat: Nothing }
    else if n >= 3 then
      let
        iAdd = n - 2
        iDel = n - 1
        last = fromMaybe "" $ Array.index parts iDel
        prev = fromMaybe "" $ Array.index parts iAdd
      in
        case matchSignedStat last, matchSignedStat prev of
          Just delS, Just addS
            | CU.take 1 delS == "-" && CU.take 1 addS == "+" ->
                { file: String.joinWith " " $ Array.take iAdd parts, addStat: Just addS, delStat: Just delS }
          _, _ ->
            { file: String.joinWith " " parts, addStat: Nothing, delStat: Nothing }
    else if n == 2 then
      case matchSignedStat =<< Array.index parts 1 of
        Just stat ->
          { file: fromMaybe "snippet" $ Array.head parts, addStat: Just stat, delStat: Nothing }
        Nothing ->
          { file: String.joinWith " " parts, addStat: Nothing, delStat: Nothing }
    else
      { file: fromMaybe "snippet" $ Array.head parts, addStat: Nothing, delStat: Nothing }

parseToolDisplayCardInfo :: String -> Maybe ToolDisplayMeta
parseToolDisplayCardInfo info =
  case Array.uncons (infoWords info) of
    Just { head: h, tail: tl } | h == toolDisplayCardPrefix -> Just (parseFileAndStats tl)
    _ -> Nothing

parseDiffFenceInfo :: String -> Maybe ToolDisplayMeta
parseDiffFenceInfo info =
  case Array.uncons (infoWords info) of
    Just { head: h, tail: tl } | h == diffFencePrefix -> Just (parseFileAndStats tl)
    _ -> Nothing

parseTerminalInfo :: String -> Maybe String
parseTerminalInfo info =
  case Array.uncons (infoWords info) of
    Just { head: h, tail: tl } | h == terminalFencePrefix -> Just (String.joinWith " " tl)
    _ -> Nothing

splitTerminalContent :: String -> { command :: String, output :: String }
splitTerminalContent content =
  let
    ls = BBH.normalizeLines content
    isSep s =
      let t = String.trim s
      in t == "---" || t == "----" || (String.length t >= 3 && all (\c -> c == '-') (CU.toCharArray t))
    idx = Array.findIndex isSep ls
  in
    case idx of
      Nothing -> { command: content, output: "" }
      Just i ->
        { command: String.joinWith "\n" (Array.take i ls)
        , output: String.joinWith "\n" (Array.drop (i + 1) ls)
        }

simpleHash :: String -> Int
simpleHash str =
  Array.foldl (\acc ch -> (acc * 33 + fromEnum ch) `mod` 1000003) 0 (CU.toCharArray str)

fenceToBodyBlock :: MdToken -> Maybe BodyBlock
fenceToBodyBlock (MdToken t)
  | t.type /= "fence" = Nothing
  | otherwise =
    case parseDiffFenceInfo t.info of
      Just meta ->
        Just $ BodyDiffCard
          { id: "diff-card-" <> slugify meta.file <> "-" <> show (simpleHash (t.info <> t.content))
          , file: meta.file
          , addStat: meta.addStat
          , delStat: meta.delStat
          , content: t.content
          }
      Nothing ->
        case parseToolDisplayCardInfo t.info of
          Just meta ->
            Just $ BodyToolCard
              { id: "tool-card-" <> slugify meta.file <> "-" <> show (simpleHash (t.info <> t.content))
              , file: meta.file
              , addStat: meta.addStat
              , delStat: meta.delStat
              , content: t.content
              }
          Nothing ->
            case parseTerminalInfo t.info of
              Just titleStr ->
                let
                  parts = splitTerminalContent t.content
                  base = "term-" <> show (simpleHash (t.info <> titleStr <> parts.command))
                in
                  Just $ BodyTerminal
                    { id: base
                    , title: titleStr
                    , command: parts.command
                    , output: parts.output
                    }
              Nothing -> Nothing

snocMergedProse :: Array BodyBlock -> String -> Array BodyBlock
snocMergedProse blocks raw =
  if String.length (String.trim raw) == 0 then blocks
  else
    case Array.unsnoc blocks of
      Nothing -> [ BodyProseHtml raw ]
      Just { init: i, last: BodyProseHtml prev } -> Array.snoc i (BodyProseHtml (prev <> raw))
      Just { init: i, last: b } -> Array.snoc (Array.snoc i b) (BodyProseHtml raw)

tokensToBlocksAndHtml :: Array MdToken -> { html :: String, blocks :: Array BodyBlock }
tokensToBlocksAndHtml tokens =
  let
    step { acc, blocks } tok =
      case fenceToBodyBlock tok of
        Just b ->
          { acc: ""
          , blocks: Array.snoc (snocMergedProse blocks acc) b
          }
        Nothing ->
          { acc: acc <> renderBlockToken tok
          , blocks: blocks
          }
    { acc: trailing, blocks: bs0 } = Array.foldl step { acc: "", blocks: [] } tokens
    blocksFin = snocMergedProse bs0 trailing
    html = foldMap BBH.renderBodyBlock blocksFin
  in
    { html, blocks: blocksFin }

renderBlockToken :: MdToken -> String
renderBlockToken (MdToken t)
  | t.hidden = ""
  | otherwise = case t.type of
      "inline" -> renderInline (MdToken t)
      "fence" ->
        let lang = if t.info == "" then "" else " class=\"language-" <> escapeAttr t.info <> "\""
        in "<pre><code" <> lang <> ">" <> escapeHtml t.content <> "</code></pre>\n"
      "code_block" -> "<pre><code>" <> escapeHtml t.content <> "</code></pre>\n"
      "hr" -> "<hr />\n"
      "html_block" -> t.content
      _ ->
        if t.nesting == 1 && t.tag /= "" then "<" <> t.tag <> renderAttrs t.attrs <> ">"
        else if t.nesting == -1 && t.tag /= "" then "</" <> t.tag <> ">\n"
        else ""

injectHeadingIdsAndToc :: Array MdToken -> { tokens :: Array MdToken, toc :: Array TocRow }
injectHeadingIdsAndToc tokens = go 0 Map.empty [] []
  where
  len = Array.length tokens

  go i seen accT accC
    | i >= len = { tokens: Array.reverse accT, toc: Array.reverse accC }
    | otherwise =
        case Array.index tokens i of
          Nothing -> { tokens: Array.reverse accT, toc: Array.reverse accC }
          Just tok@(MdToken h) ->
            if h.type == "heading_open" && (h.tag == "h2" || h.tag == "h3") then
              case Array.index tokens (i + 1) of
                Just inl@(MdToken it) | it.type == "inline" ->
                  let
                    title = String.trim $ collectInlineText inl
                    base0 = slugify title
                    base = if base0 == "" then "section" else base0
                    count = fromMaybe 0 $ Map.lookup base seen
                    seen' = Map.insert base (count + 1) seen
                    id = if count == 0 then base else base <> "-" <> show (count + 1)
                    patched = MdToken h { attrs = Array.snoc h.attrs { key: "id", value: id } }
                    level = if h.tag == "h3" then 3 else 2
                    skip = shouldSkipTocHeading title id
                    accC' = if skip then accC else Array.cons { id, title, level } accC
                  in
                    go (i + 1) seen' (Array.cons patched accT) accC'
                _ ->
                  go (i + 1) seen (Array.cons tok accT) accC
            else
              go (i + 1) seen (Array.cons tok accT) accC

renderDocument :: String -> { html :: String, toc :: Array TocRow, blocks :: Array BodyBlock }
renderDocument src =
  let
    ts = parse src
    { tokens, toc } = injectHeadingIdsAndToc ts
    out = tokensToBlocksAndHtml tokens
  in
    { html: out.html, toc, blocks: out.blocks }