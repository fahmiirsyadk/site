module BuildContent.MdHtml
  ( renderMarkdownHtml
  , buildToc
  ) where

import Prelude

import BuildContent.Slugify (slugify)
import Data.Array as Array
import Data.Foldable (foldMap)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Data.Tuple (Tuple(..))
import MarkdownIt (MdToken(..), MdAttr, parse)

type TocRow =
  { id :: String
  , title :: String
  , level :: Int
  }

escapeHtml :: String -> String
escapeHtml s =
  String.replaceAll (String.Pattern "&") (String.Replacement "&amp;") $
    String.replaceAll (String.Pattern "<") (String.Replacement "&lt;") $
      String.replaceAll (String.Pattern ">") (String.Replacement "&gt;") $
        String.replaceAll (String.Pattern "\"") (String.Replacement "&quot;") s

escapeAttr :: String -> String
escapeAttr = escapeHtml

renderAttrs :: Array MdAttr -> String
renderAttrs = foldMap \a -> " " <> a.key <> "=\"" <> escapeAttr a.value <> "\""

collectInlineText :: MdToken -> String
collectInlineText (MdToken t) =
  case t.type of
    "text" -> t.content
    "softbreak" -> " "
    "hardbreak" -> "\n"
    _ -> foldMap collectInlineText t.children

shouldSkipTocHeading :: String -> String -> Boolean
shouldSkipTocHeading title idBase =
  let
    n = String.trim $ String.toLower title
  in
    n == "" || n == "table of contents" || n == "toc" || idBase == "table-of-contents"

renderInlineTok :: MdToken -> String
renderInlineTok (MdToken t)
  | t.hidden = ""
  | otherwise = case t.type of
      "text" -> escapeHtml t.content
      "html_inline" -> t.content
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
        else
          ""

renderInlineChildren :: Array MdToken -> String
renderInlineChildren = foldMap renderInlineTok

renderInline :: MdToken -> String
renderInline (MdToken t) =
  if t.type == "inline" then renderInlineChildren t.children
  else renderInlineTok (MdToken t)

renderBlockToken :: MdToken -> String
renderBlockToken (MdToken t)
  | t.hidden = ""
  | otherwise = case t.type of
      "inline" -> renderInline (MdToken t)
      "fence" ->
        let
          lang =
            if String.length t.info == 0 then ""
            else " class=\"language-" <> escapeAttr t.info <> "\""
        in
          "<pre><code" <> lang <> ">" <> escapeHtml t.content <> "</code></pre>\n"
      "code_block" -> "<pre><code>" <> escapeHtml t.content <> "</code></pre>\n"
      "hr" -> "<hr />\n"
      "html_block" -> t.content
      _ ->
        if t.nesting == 1 && t.tag /= "" then
          "<" <> t.tag <> renderAttrs t.attrs <> ">"
        else if t.nesting == -1 && t.tag /= "" then
          "</" <> t.tag <> ">\n"
        else if t.type == "bullet_list_open" || t.type == "ordered_list_open" || t.type == "blockquote_open" then
          "<" <> t.tag <> renderAttrs t.attrs <> ">\n"
        else if t.type == "bullet_list_close" || t.type == "ordered_list_close" || t.type == "blockquote_close" then
          "</" <> t.tag <> ">\n"
        else if t.type == "list_item_open" then
          "<" <> t.tag <> renderAttrs t.attrs <> ">"
        else if t.type == "list_item_close" then
          "</" <> t.tag <> ">\n"
        else if t.type == "table_open" || t.type == "thead_open" || t.type == "tbody_open" || t.type == "tr_open" || t.type == "th_open" || t.type == "td_open" then
          "<" <> t.tag <> renderAttrs t.attrs <> ">"
        else if t.type == "table_close" || t.type == "thead_close" || t.type == "tbody_close" || t.type == "tr_close" || t.type == "th_close" || t.type == "td_close" then
          "</" <> t.tag <> ">\n"
        else
          ""

renderBlocks :: Array MdToken -> String
renderBlocks = foldMap renderBlockToken

injectHeadingIds :: Array MdToken -> Tuple (Array MdToken) (Map.Map String Int)
injectHeadingIds tokens =
  go 0 Map.empty tokens
  where
  go :: Int -> Map.Map String Int -> Array MdToken -> Tuple (Array MdToken) (Map.Map String Int)
  go i seen acc =
    if i >= Array.length tokens then
      Tuple acc seen
    else
      case Array.index tokens i of
        Nothing -> Tuple acc seen
        Just (MdToken h) ->
          if h.type == "heading_open" && (h.tag == "h2" || h.tag == "h3") then
            case Array.index tokens (i + 1) of
              Just inl@(MdToken inlTok) | inlTok.type == "inline" ->
                let
                  title = String.trim $ collectInlineText inl
                  idBase = slugify title
                  idBase' = if idBase == "" then "section" else idBase
                  count = fromMaybe 0 $ Map.lookup idBase' seen
                  seen' = Map.insert idBase' (count + 1) seen
                  id =
                    if count == 0 then
                      idBase'
                    else
                      idBase' <> "-" <> show (count + 1)
                  attrs = Array.snoc h.attrs { key: "id", value: id }
                  patched = MdToken h { attrs = attrs }
                  arr' = fromMaybe acc $ Array.updateAt i patched acc
                in
                  go (i + 1) seen' arr'
              _ ->
                go (i + 1) seen acc
          else
            go (i + 1) seen acc

findAttrId :: Array MdAttr -> Maybe String
findAttrId attrs = Array.find (\a -> a.key == "id") attrs <#> _.value

buildTocFromInjected :: Array MdToken -> Array TocRow
buildTocFromInjected tokens =
  go 0 []
  where
  go i toc =
    if i >= Array.length tokens then
      toc
    else
      case Array.index tokens i of
        Nothing -> toc
        Just (MdToken h) ->
          if h.type == "heading_open" && (h.tag == "h2" || h.tag == "h3") then
            case Array.index tokens (i + 1) of
              Just inl@(MdToken inlTok) | inlTok.type == "inline" ->
                let
                  title = String.trim $ collectInlineText inl
                  idBase = slugify title
                  idBase' = if idBase == "" then "section" else idBase
                  mbId = findAttrId h.attrs
                  level = case h.tag of
                    "h2" -> 2
                    "h3" -> 3
                    _ -> 2
                in
                  case mbId of
                    Nothing -> go (i + 1) toc
                    Just id ->
                      if shouldSkipTocHeading title idBase' then
                        go (i + 1) toc
                      else
                        go (i + 1) (Array.snoc toc { id, title, level })
              _ ->
                go (i + 1) toc
          else
            go (i + 1) toc

renderMarkdownHtml :: String -> String
renderMarkdownHtml src =
  let
    ts = parse src
    Tuple ts' _ = injectHeadingIds ts
  in
    renderBlocks ts'

buildToc :: String -> Array { id :: String, title :: String, level :: Int }
buildToc src =
  let
    ts = parse src
    Tuple ts' _ = injectHeadingIds ts
  in
    map (\r -> { id: r.id, title: r.title, level: r.level }) (buildTocFromInjected ts')
