module BuildContent.MdHtml
  ( renderMarkdownHtml
  , buildToc
  , renderDocument
  ) where

import Prelude

import BuildContent.MarkdownParse (parse)
import BuildContent.Slugify (slugify)
import Data.Array as Array
import Data.Foldable (foldMap)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import MarkdownIt (MdToken(..), MdAttr)

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

renderBlocks :: Array MdToken -> String
renderBlocks = foldMap renderBlockToken

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

renderDocument :: String -> { html :: String, toc :: Array TocRow }
renderDocument src =
  let
    ts = parse src
    { tokens, toc } = injectHeadingIdsAndToc ts
  in
    { html: renderBlocks tokens, toc }

renderMarkdownHtml :: String -> String
renderMarkdownHtml src = (renderDocument src).html

buildToc :: String -> Array { id :: String, title :: String, level :: Int }
buildToc src = (renderDocument src).toc