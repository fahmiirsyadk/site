-- | HTML string rendering for structured `BodyBlock` values (browser + build).
-- | Kept separate from `BuildContent.MdHtml` so the client bundle does not pull markdown-it.
module BodyBlockHtml
  ( escapeHtml
  , normalizeLines
  , renderBodyBlock
  , renderCopyButtonHtml
  , renderDiffCardBodyHtml
  , renderDiffToolCardWithId
  , renderTerminalShell
  , renderToolCardBodyHtml
  , renderToolDisplayCardWithId
  , toolDisplayStatsInnerHtml
  ) where

import Prelude

import BuildContent.CodeHighlight (highlightCodeLine)
import Data.Array (mapWithIndex)
import Data.Array as Array
import Data.Enum (fromEnum)
import Data.Foldable (fold, foldMap)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.String as String
import Data.String.CodeUnits as CU
import Types (BodyBlock(..))

escapeHtml :: String -> String
escapeHtml =
  String.replaceAll (String.Pattern "&") (String.Replacement "&amp;")
    >>> String.replaceAll (String.Pattern "<") (String.Replacement "&lt;")
    >>> String.replaceAll (String.Pattern ">") (String.Replacement "&gt;")
    >>> String.replaceAll (String.Pattern "\"") (String.Replacement "&quot;")
    >>> String.replaceAll (String.Pattern "'") (String.Replacement "&#39;")

escapeAttr :: String -> String
escapeAttr = escapeHtml

normalizeLines :: String -> Array String
normalizeLines s =
  map (String.replaceAll (String.Pattern "\r") (String.Replacement ""))
    $ String.split (String.Pattern "\n") s

type ToolDisplayMeta =
  { file :: String
  , addStat :: Maybe String
  , delStat :: Maybe String
  }

toolDisplayStatsInnerHtml :: Maybe String -> Maybe String -> String
toolDisplayStatsInnerHtml = statsHtml

statsHtml :: Maybe String -> Maybe String -> String
statsHtml addStat delStat =
  case addStat, delStat of
    Nothing, Nothing -> ""
    _, _ ->
      "<div class=\"flex shrink-0 items-center gap-2 px-2 font-mono text-[12px] leading-none\">"
        <> maybe "" (\s -> "<span class=\"font-medium text-green-600\">" <> escapeHtml s <> "</span>") addStat
        <> maybe "" (\s -> "<span class=\"font-medium text-red-600\">" <> escapeHtml s <> "</span>") delStat
        <> "</div>"

toolDisplayCardShell :: String -> ToolDisplayMeta -> String -> String -> String -> String
toolDisplayCardShell id meta innerBody extraCardClass expandSrOnly =
  let
    stats = statsHtml meta.addStat meta.delStat
    cardClass =
      if extraCardClass == "" then
        "not-prose my-2 overflow-hidden rounded-lg border border-neutral-200 bg-neutral-50 dark:border-neutral-700 dark:bg-neutral-950 is-expanded"
      else
        "not-prose my-2 overflow-hidden rounded-lg border border-neutral-200 bg-neutral-50 dark:border-neutral-700 dark:bg-neutral-950 is-expanded "
        <> extraCardClass
    bodyCls = "tool-display-body relative min-h-0 bg-neutral-50 dark:bg-neutral-900"
    btnCls =
      String.joinWith " "
        [ "tool-display-expand-btn flex h-8 w-full cursor-pointer items-center justify-center border-t border-neutral-100 text-neutral-400"
        , "transition-colors hover:bg-neutral-50 hover:text-neutral-600 dark:border-neutral-800 dark:hover:bg-neutral-800 dark:hover:text-neutral-300"
        ]
  in
    String.joinWith ""
      [ "<div data-component=\"tool-display-card\" data-block-id=\""
      , escapeAttr id
      , "\" class=\""
      , cardClass
      , "\">"
      , "<div class=\"flex items-center justify-between gap-2 border-b border-neutral-200 bg-neutral-100 px-2 dark:border-neutral-700 dark:bg-neutral-900\">"
      , "<div class=\"flex min-h-7 min-w-0 flex-1 items-center gap-2 py-1\">"
      , "<span class=\"truncate text-[12px] font-medium text-neutral-800 dark:text-neutral-200\">"
      , escapeHtml meta.file
      , "</span></div>"
      , stats
      , "</div>"
      , "<div class=\""
      , bodyCls
      , "\">"
      , innerBody
      , "</div>"
      , "<button type=\"button\" class=\""
      , btnCls
      , "\" data-tool-display-toggle aria-expanded=\"true\" aria-label=\""
      , escapeAttr expandSrOnly
      , "\">"
      , "<span class=\"sr-only\">"
      , escapeHtml expandSrOnly
      , "</span>"
      , "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"tool-display-chevron h-3.5 w-3.5 shrink-0\" aria-hidden=\"true\"><path d=\"m6 9 6 6 6-6\"></path></svg>"
      , "</button>"
      , "</div>\n"
      ]

renderPlainCodeRow :: Int -> String -> String
renderPlainCodeRow num line =
  String.joinWith ""
    [ "<div class=\"flex hover:bg-neutral-50/80 dark:hover:bg-neutral-800/60\">"
    , "<div class=\"w-12 shrink-0 select-none pr-3 text-right text-neutral-400 tabular-nums\">"
    , show num
    , "</div>"
    , "<div class=\"min-w-0 flex-1 px-2 whitespace-pre-wrap break-words text-neutral-800 dark:text-neutral-200\">"
    , highlightCodeLine line
    , "</div>"
    , "</div>"
    ]

renderToolCardBodyHtml :: String -> String
renderToolCardBodyHtml = renderLineNumberedCodeBody

renderLineNumberedCodeBody :: String -> String
renderLineNumberedCodeBody content =
  let
    ls = normalizeLines content
    rows = mapWithIndex (\i line -> renderPlainCodeRow (i + 1) line) ls
  in
    "<div class=\"code-line-numbered-root font-mono text-[13px] leading-6 px-1 py-1\" data-component=\"code-block-lines\">"
      <> fold rows
      <> "</div>"

renderToolDisplayCardWithId :: String -> ToolDisplayMeta -> String -> String
renderToolDisplayCardWithId cardId meta content =
  toolDisplayCardShell cardId meta (renderLineNumberedCodeBody content) "" "Expand code block"

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

infoWords :: String -> Array String
infoWords s =
  Array.filter (\w -> String.length (String.trim w) > 0)
    $ map String.trim
    $ String.split (String.Pattern " ") s

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

renderDiffCardBodyHtml :: String -> String
renderDiffCardBodyHtml content =
  renderDiffBody (buildDiffRows content)

renderDiffBody :: Array DiffRow -> String
renderDiffBody rows =
  "<div class=\"font-mono text-[13px] leading-6 tabular-nums\" data-component=\"diff-body\">"
    <> foldMap renderDiffRow rows
    <> "</div>"

renderDiffToolCardWithId :: String -> ToolDisplayMeta -> String -> String
renderDiffToolCardWithId cardId meta content =
  toolDisplayCardShell cardId meta (renderDiffBody (buildDiffRows content)) "" "Expand diff"

renderCopyButtonHtml :: String -> String
renderCopyButtonHtml cmd =
  let
    cmdAttr = escapeAttr cmd
  in
    String.joinWith ""
      [ "<button type=\"button\" class=\"terminal-copy relative flex h-6 w-6 items-center justify-center rounded opacity-0 transition hover:bg-neutral-100 group-hover:opacity-100\""
      , " aria-label=\"Copy command\" title=\"Copy\" data-terminal-copy data-command=\""
      , cmdAttr
      , "\">"
      , "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"text-neutral-400\"><rect width=\"14\" height=\"14\" x=\"8\" y=\"8\" rx=\"2\" ry=\"2\"></rect><path d=\"M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2\"></path></svg>"
      , "</button>"
      ]

renderCmdRowHtml :: String -> String
renderCmdRowHtml cmd =
  String.joinWith ""
    [ "<div class=\"group flex items-start gap-2 py-0.5\">"
    , "<div class=\"flex min-w-0 flex-1 items-start gap-1.5\">"
    , "<span class=\"select-none font-semibold text-neutral-400\">$</span>"
    , "<code class=\"min-w-0 whitespace-pre-wrap break-words font-mono text-[13px] text-neutral-800 dark:text-neutral-200\">"
    , escapeHtml cmd
    , "</code>"
    , "</div>"
    , "<div class=\"flex shrink-0 items-start\">"
    , renderCopyButtonHtml cmd
    , "</div>"
    , "</div>"
    ]

renderTerminalShell :: String -> String -> String -> String -> String
renderTerminalShell base title command output =
  let
    bodyId = base <> "-body"
    outHtml = escapeHtml output
    titleHtml = if String.trim title == "" then "Command" else escapeHtml title
    cmdLines =
      Array.filter (\s -> String.trim s /= "")
        $ normalizeLines command

    commandBlock :: String
    commandBlock =
      if Array.length cmdLines <= 1 then
        let cmd = fromMaybe "" (Array.head cmdLines)
        in
          "<div class=\"group flex items-start gap-2 border-b border-neutral-100 p-2 dark:border-neutral-800\" style=\"max-height:120px; overflow-y:auto;\">"
            <> "<div class=\"flex min-w-0 flex-1 items-start gap-1.5\">"
            <> "<span class=\"select-none font-semibold text-neutral-400\">$</span>"
            <> "<code class=\"min-w-0 whitespace-pre-wrap break-words font-mono text-[13px] text-neutral-800 dark:text-neutral-200\">"
            <> escapeHtml cmd
            <> "</code></div>"
            <> "<div class=\"flex shrink-0 items-start\">" <> renderCopyButtonHtml cmd <> "</div>"
            <> "</div>"
      else
        "<div class=\"border-b border-neutral-100 p-2 dark:border-neutral-800\" style=\"max-height:140px; overflow-y:auto;\">"
          <> foldMap renderCmdRowHtml cmdLines
          <> "</div>"
  in
    String.joinWith ""
      [ "<div data-component=\"tool-display-card\" data-block-id=\""
      , escapeAttr base
      , "\" class=\"terminal-card not-prose my-2 overflow-hidden rounded-lg border border-neutral-200 bg-neutral-50 dark:border-neutral-700 dark:bg-neutral-950\">"
      , "<button type=\"button\" class=\"flex w-full items-center justify-start gap-2 border-b border-neutral-200 bg-neutral-100 px-2 py-1 text-left text-[12px] text-neutral-600 hover:text-neutral-800 dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-300 dark:hover:text-neutral-100\" data-terminal-toggle data-target=\""
      , escapeAttr bodyId
      , "\" aria-expanded=\"true\" aria-controls=\""
      , escapeAttr bodyId
      , "\">"
      , "<span class=\"flex h-5 w-3 min-w-3 items-center justify-center text-neutral-400\" aria-hidden=\"true\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.25\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"terminal-chevron\" aria-hidden=\"true\"><path d=\"m9 18 6-6-6-6\"></path></svg></span>"
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
            <> "<pre class=\"m-0 min-w-full whitespace-pre px-2 py-2 font-mono text-[13px] leading-6 text-neutral-600 dark:text-neutral-300\" style=\"max-height:400px; overflow:auto;\">"
            <> outHtml
            <> "</pre>"
            <> "</div>"
      , "</div>"
      , "</div>\n"
      ]

renderBodyBlock :: BodyBlock -> String
renderBodyBlock = case _ of
  BodyProseHtml html -> html
  BodyToolCard r ->
    renderToolDisplayCardWithId r.id
      { file: r.file, addStat: r.addStat, delStat: r.delStat }
      r.content
  BodyDiffCard r ->
    renderDiffToolCardWithId r.id
      { file: r.file, addStat: r.addStat, delStat: r.delStat }
      r.content
  BodyTerminal { id, title, command, output } ->
    renderTerminalShell id title command output
