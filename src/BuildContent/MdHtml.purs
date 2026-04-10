module BuildContent.MdHtml
  ( renderMarkdownHtml
  , buildToc
  , renderDocument
  ) where

import Prelude

import BuildContent.CodeHighlight (highlightCodeLine)
import BuildContent.MarkdownParse (parse)
import BuildContent.Slugify (slugify)
import Data.Array as Array
import Data.Enum (fromEnum)
import Data.Array (mapWithIndex)
import Data.Foldable (all, fold, foldMap)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.String as String
import Data.String.CodeUnits as CU
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
    ls = normalizeLines content
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

renderTerminalToolCard :: String -> String -> String -> String -> String
renderTerminalToolCard title command output infoForId =
  let
    base = "term-" <> show (simpleHash (infoForId <> title <> command))
    bodyId = base <> "-body"
    outHtml = escapeHtml output
    titleHtml = if String.trim title == "" then "Command" else escapeHtml title
    cmdLines =
      Array.filter (\s -> String.trim s /= "")
        $ normalizeLines command

    renderCopyButton :: String -> String
    renderCopyButton cmd =
      let
        cmdAttr = escapeAttr cmd
      in
        String.joinWith ""
          [ "<button type=\"button\" class=\"terminal-copy relative flex h-6 w-6 items-center justify-center rounded opacity-0 transition hover:bg-neutral-100 group-hover:opacity-100\""
          , " aria-label=\"Copy command\" title=\"Copy\" data-command=\""
          , cmdAttr
          , "\" onclick=\"const t=this;const v=t.dataset.command||'';try{navigator.clipboard&&navigator.clipboard.writeText(v);}catch(e){};t.dataset.copied='1';t.setAttribute('title','Copied');setTimeout(()=>{delete t.dataset.copied;t.setAttribute('title','Copy');},900);\">"
          , "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"text-neutral-400\"><rect width=\"14\" height=\"14\" x=\"8\" y=\"8\" rx=\"2\" ry=\"2\"></rect><path d=\"M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2\"></path></svg>"
          , "</button>"
          ]

    renderCmdRow :: String -> String
    renderCmdRow cmd =
      String.joinWith ""
        [ "<div class=\"group flex items-start gap-2 py-0.5\">"
        , "<div class=\"flex min-w-0 flex-1 items-start gap-1.5\">"
        , "<span class=\"select-none font-semibold text-neutral-400\">$</span>"
        , "<code class=\"min-w-0 whitespace-pre-wrap break-words font-mono text-[13px] text-neutral-800\">"
        , escapeHtml cmd
        , "</code>"
        , "</div>"
        , "<div class=\"flex shrink-0 items-start\">"
        , renderCopyButton cmd
        , "</div>"
        , "</div>"
        ]

    commandBlock :: String
    commandBlock =
      if Array.length cmdLines <= 1 then
        let cmd = fromMaybe "" (Array.head cmdLines)
        in
          "<div class=\"group flex items-start gap-2 border-b border-neutral-100 p-2\" style=\"max-height:120px; overflow-y:auto;\">"
            <> "<div class=\"flex min-w-0 flex-1 items-start gap-1.5\">"
            <> "<span class=\"select-none font-semibold text-neutral-400\">$</span>"
            <> "<code class=\"min-w-0 whitespace-pre-wrap break-words font-mono text-[13px] text-neutral-800\">"
            <> escapeHtml cmd
            <> "</code></div>"
            <> "<div class=\"flex shrink-0 items-start\">" <> renderCopyButton cmd <> "</div>"
            <> "</div>"
      else
        "<div class=\"border-b border-neutral-100 p-2\" style=\"max-height:140px; overflow-y:auto;\">"
          <> foldMap renderCmdRow cmdLines
          <> "</div>"
  in
    String.joinWith ""
      [ "<div data-component=\"tool-display-card\" class=\"terminal-card not-prose my-2 overflow-hidden rounded-lg border border-neutral-200 bg-white\">"
      , "<button class=\"flex w-full items-center justify-start gap-2 border-b border-neutral-200 bg-neutral-50 px-2 py-1 text-left text-[12px] text-neutral-600 hover:text-neutral-800\" type=\"button\" aria-expanded=\"true\" aria-controls=\""
      , escapeAttr bodyId
      , "\" onclick=\"const b=this;const e=b.getAttribute('aria-expanded')==='true';b.setAttribute('aria-expanded',String(!e));const p=document.getElementById('"
      , escapeAttr bodyId
      , "');p.hidden=e;const c=b.querySelector('svg');if(c){c.style.transform=e?'rotate(0deg)':'rotate(90deg)'}\">"
      , "<span class=\"flex h-5 w-3 min-w-3 items-center justify-center text-neutral-400\" aria-hidden=\"true\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.25\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"terminal-chevron\" aria-hidden=\"true\" style=\"transform:rotate(90deg)\"><path d=\"m9 18 6-6-6-6\"></path></svg></span>"
      , "<span class=\"min-w-0 flex-1 truncate font-medium\">"
      , titleHtml
      , "</span>"
      , "</button>"
      , commandBlock
      , "<div id=\""
      , escapeAttr bodyId
      , "\">"
      , if String.trim output == "" then "" else
          "<div class=\"overflow-x-auto\">"
            <> "<pre class=\"m-0 min-w-full whitespace-pre px-2 py-2 font-mono text-[13px] leading-6 text-neutral-600\" style=\"max-height:400px; overflow:auto;\">"
            <> outHtml
            <> "</pre>"
            <> "</div>"
      , "</div>"
      , "</div>\n"
      ]

readUInt :: String -> Maybe Int
readUInt s =
  let
    chs = CU.toCharArray s
    step acc c =
      let
        d = fromEnum c - fromEnum '0'
      in
        if d >= 0 && d <= 9 then acc * 10 + d else -1
  in
    if Array.null chs then Nothing
    else
      let
        n = Array.foldl step 0 chs
      in
        if n >= 0 then Just n else Nothing

-- | `+10,7` style token after `@@` hunk header → new-file start line.
parsePlusRangeStart :: String -> Maybe Int
parsePlusRangeStart w =
  if CU.take 1 w /= "+" then Nothing
  else
    let
      body = CU.drop 1 w
    in
      case Array.head (String.split (String.Pattern ",") body) of
        Just start -> readUInt start
        Nothing -> Nothing

hunkNewLineStart :: String -> Maybe Int
hunkNewLineStart line =
  if not (String.contains (String.Pattern "@@") (String.trim line)) then Nothing
  else
    Array.findMap parsePlusRangeStart (infoWords line)

isDiffFileHeader :: String -> Boolean
isDiffFileHeader line =
  let
    t = String.trim line
  in
    CU.take 3 t == "---" || CU.take 3 t == "+++"

data DiffKind
  = DAdd
  | DDel
  | DCtx

derive instance eqDiffKind :: Eq DiffKind

type DiffRow =
  { numTxt :: String
  , kind :: DiffKind
  , body :: String
  }

type DiffAcc =
  { rows :: Array DiffRow
  , newNum :: Int
  }

normalizeLines :: String -> Array String
normalizeLines s =
  map (String.replaceAll (String.Pattern "\r") (String.Replacement ""))
    $ String.split (String.Pattern "\n") s

classifyDiffLine :: String -> Maybe { kind :: DiffKind, rest :: String }
classifyDiffLine raw =
  let
    line = String.replaceAll (String.Pattern "\r") (String.Replacement "") raw
  in
    if String.length line == 0 then
      Just { kind: DCtx, rest: "" }
    else
      case CU.take 3 line of
        "+++" -> Nothing
        "---" -> Nothing
        _ ->
          case CU.take 1 line of
            "+" -> Just { kind: DAdd, rest: CU.drop 1 line }
            "-" -> Just { kind: DDel, rest: CU.drop 1 line }
            " " -> Just { kind: DCtx, rest: CU.drop 1 line }
            _ -> Just { kind: DCtx, rest: line }

processDiffLine :: DiffAcc -> String -> DiffAcc
processDiffLine acc line =
  if isDiffFileHeader line then
    acc
  else if String.contains (String.Pattern "@@") (String.trim line) then
    case hunkNewLineStart line of
      Just n -> acc { newNum = n }
      Nothing -> acc
  else
    case classifyDiffLine line of
      Nothing -> acc
      Just { kind, rest } ->
        case kind of
          DDel ->
            acc
              { rows =
                  Array.snoc acc.rows { numTxt: "", kind: DDel, body: rest }
              }
          DAdd ->
            acc
              { rows =
                  Array.snoc acc.rows { numTxt: show acc.newNum, kind: DAdd, body: rest }
              , newNum = acc.newNum + 1
              }
          DCtx ->
            acc
              { rows =
                  Array.snoc acc.rows { numTxt: show acc.newNum, kind: DCtx, body: rest }
              , newNum = acc.newNum + 1
              }

buildDiffRows :: String -> Array DiffRow
buildDiffRows content =
  let
    ls = normalizeLines content
  in
    (Array.foldl processDiffLine { rows: [], newNum: 1 } ls).rows

diffKindAttr :: DiffKind -> String
diffKindAttr = case _ of
  DAdd -> "add"
  DDel -> "del"
  DCtx -> "ctx"

renderDiffRow :: DiffRow -> String
renderDiffRow r =
  let
    rowCls =
      case r.kind of
        DAdd -> "flex bg-emerald-50/80 hover:bg-emerald-50/90"
        DDel -> "flex bg-rose-50/80 hover:bg-rose-50/90"
        DCtx -> "flex hover:bg-neutral-50/80"
    barCls =
      case r.kind of
        DAdd -> "w-[3px] shrink-0 self-stretch bg-emerald-500/90"
        DDel -> "w-[3px] shrink-0 self-stretch bg-rose-500/90"
        DCtx -> "hidden w-0 shrink-0"
    textCls =
      case r.kind of
        DAdd -> "flex-1 min-w-0 whitespace-pre-wrap px-3 text-emerald-900"
        DDel -> "flex-1 min-w-0 whitespace-pre-wrap px-3 text-rose-900"
        DCtx -> "flex-1 min-w-0 whitespace-pre-wrap px-2 text-neutral-800"
  in
    String.joinWith ""
      [ "<div class=\""
      , rowCls
      , "\" data-diff-kind=\""
      , diffKindAttr r.kind
      , "\">"
      , "<div class=\"w-12 shrink-0 select-none pr-3 text-right text-neutral-400 tabular-nums\">"
      , escapeHtml r.numTxt
      , "</div>"
      , "<div class=\""
      , barCls
      , "\" aria-hidden=\"true\"></div>"
      , "<div class=\""
      , textCls
      , "\">"
      , highlightCodeLine r.body
      , "</div>"
      , "</div>"
      ]

renderDiffBody :: Array DiffRow -> String
renderDiffBody rows =
  "<div class=\"font-mono text-[13px] leading-6 tabular-nums\" data-component=\"diff-body\">"
    <> foldMap renderDiffRow rows
    <> "</div>"

-- | Shared chrome: header, collapsible body, chevron (checkbox + label).
-- | Expand/collapse is styled in css/style.css with :has(.tool-display-toggle:checked) so each
-- | card is independent under flat markdown HTML (Tailwind peer-checked ~ can match wrong siblings).
toolDisplayCardShell :: String -> ToolDisplayMeta -> String -> String -> String -> String
toolDisplayCardShell id meta innerBody extraCardClass expandSrOnly =
  let
    stats = statsHtml meta.addStat meta.delStat
    cardClass =
      if extraCardClass == "" then
        "not-prose my-2 overflow-hidden rounded-lg border border-neutral-200 bg-white"
      else
        "not-prose my-2 overflow-hidden rounded-lg border border-neutral-200 bg-white " <> extraCardClass
    bodyCls = "tool-display-body relative min-h-0 bg-white"
    labelCls =
      String.joinWith " "
        [ "flex h-8 w-full cursor-pointer items-center justify-center border-t border-neutral-100 text-neutral-400"
        , "transition-colors hover:bg-neutral-50 hover:text-neutral-600"
        ]
  in
    String.joinWith ""
      [ "<div data-component=\"tool-display-card\" class=\""
      , cardClass
      , "\">"
      , "<input type=\"checkbox\" id=\""
      , escapeAttr id
      , "\" class=\"tool-display-toggle\" tabindex=\"-1\" autocomplete=\"off\" />"
      , "<div class=\"flex items-center justify-between gap-2 border-b border-neutral-200 bg-neutral-50 px-2\">"
      , "<div class=\"flex min-h-7 min-w-0 flex-1 items-center gap-2 py-1\">"
      , "<span class=\"truncate text-[12px] font-medium text-neutral-800\">"
      , escapeHtml meta.file
      , "</span></div>"
      , stats
      , "</div>"
      , "<div class=\""
      , bodyCls
      , "\">"
      , innerBody
      , "</div>"
      , "<label for=\""
      , escapeAttr id
      , "\" class=\""
      , labelCls
      , "\">"
      , "<span class=\"sr-only\">"
      , escapeHtml expandSrOnly
      , "</span>"
      , "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"tool-display-chevron h-3.5 w-3.5 shrink-0\" aria-hidden=\"true\"><path d=\"m6 9 6 6 6-6\"></path></svg>"
      , "</label>"
      , "</div>\n"
      ]

renderDiffToolCard :: ToolDisplayMeta -> String -> String -> String
renderDiffToolCard meta content infoForId =
  let
    id = "diff-card-" <> slugify meta.file <> "-" <> show (simpleHash (infoForId <> content))
    rows = buildDiffRows content
    body = renderDiffBody rows
  in
    toolDisplayCardShell id meta body "" "Expand diff"

simpleHash :: String -> Int
simpleHash str =
  Array.foldl (\acc ch -> (acc * 33 + fromEnum ch) `mod` 1000003) 0 (CU.toCharArray str)

statsHtml :: Maybe String -> Maybe String -> String
statsHtml addStat delStat =
  case addStat, delStat of
    Nothing, Nothing -> ""
    _, _ ->
      "<div class=\"flex shrink-0 items-center gap-2 px-2 font-mono text-[12px] leading-none\">"
        <> maybe "" (\s -> "<span class=\"font-medium text-green-600\">" <> escapeHtml s <> "</span>") addStat
        <> maybe "" (\s -> "<span class=\"font-medium text-red-600\">" <> escapeHtml s <> "</span>") delStat
        <> "</div>"

renderPlainCodeRow :: Int -> String -> String
renderPlainCodeRow num line =
  String.joinWith ""
    [ "<div class=\"flex hover:bg-neutral-50/80\">"
    , "<div class=\"w-12 shrink-0 select-none pr-3 text-right text-neutral-400 tabular-nums\">"
    , show num
    , "</div>"
    , "<div class=\"min-w-0 flex-1 px-2 whitespace-pre-wrap break-words text-neutral-800\">"
    , highlightCodeLine line
    , "</div>"
    , "</div>"
    ]

renderLineNumberedCodeBody :: String -> String
renderLineNumberedCodeBody content =
  let
    ls = normalizeLines content
    rows = mapWithIndex (\i line -> renderPlainCodeRow (i + 1) line) ls
  in
    "<div class=\"code-line-numbered-root font-mono text-[13px] leading-6 px-1 py-1\" data-component=\"code-block-lines\">"
      <> fold rows
      <> "</div>"

renderToolDisplayCard :: ToolDisplayMeta -> String -> String -> String
renderToolDisplayCard meta content infoForId =
  let
    id = "tool-card-" <> slugify meta.file <> "-" <> show (simpleHash (infoForId <> content))
    inner = renderLineNumberedCodeBody content
  in
    toolDisplayCardShell id meta inner "" "Expand code block"

renderFence :: MdToken -> String
renderFence (MdToken t) =
  case parseDiffFenceInfo t.info of
    Just meta -> renderDiffToolCard meta t.content t.info
    Nothing ->
      case parseToolDisplayCardInfo t.info of
        Just meta -> renderToolDisplayCard meta t.content t.info
        Nothing ->
          case parseTerminalInfo t.info of
            Just title ->
              let parts = splitTerminalContent t.content
              in renderTerminalToolCard title parts.command parts.output t.info
            Nothing ->
              let
                lang = if t.info == "" then "" else " class=\"language-" <> escapeAttr t.info <> "\""
              in
                "<pre><code" <> lang <> ">" <> escapeHtml t.content <> "</code></pre>\n"

renderBlockToken :: MdToken -> String
renderBlockToken (MdToken t)
  | t.hidden = ""
  | otherwise = case t.type of
      "inline" -> renderInline (MdToken t)
      "fence" -> renderFence (MdToken t)
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