module Components.TerminalCard (terminalCard) where

import Prelude

import BodyBlockHtml as BBH
import Data.Array as Array
import Data.Maybe (fromMaybe)
import Data.String as String
import Luna.Html (Html, attr, prop, unsafeRawHtml)
import Luna.Html as H
import Luna.Html.Events (always_, onClick)

-- | Luna-rendered terminal card; copy still uses `data-terminal-copy` delegation in Main.js.
terminalCard :: forall a. Boolean -> a -> { id :: String, title :: String, command :: String, output :: String } -> Html a
terminalCard expanded toggleAct p =
  let
    bodyElId = p.id <> "-body"
    titleTxt = if String.trim p.title == "" then "Command" else p.title
    cmdLines = Array.filter (\s -> String.trim s /= "") (BBH.normalizeLines p.command)
    cmdCode s =
      H.code
        [ H.classes [ "min-w-0", "whitespace-pre-wrap", "break-words", "font-mono", "text-[13px]", "text-neutral-800", "dark:text-neutral-200" ]
        , prop "innerHTML" (BBH.escapeHtml s)
        ]
        []
    cmdRow c =
      H.div [ H.classes [ "group", "flex", "items-start", "gap-2", "py-0.5" ] ]
        [ H.div [ H.classes [ "flex", "min-w-0", "flex-1", "items-start", "gap-1.5" ] ]
            [ H.span [ H.classes [ "select-none", "font-semibold", "text-neutral-400" ] ] [ H.text "$" ]
            , cmdCode c
            ]
        , H.div [ H.classes [ "flex", "shrink-0", "items-start" ] ]
            [ unsafeRawHtml (BBH.renderCopyButtonHtml c) ]
        ]
    commandSection =
      if Array.length cmdLines <= 1 then
        let cmd = fromMaybe "" (Array.head cmdLines)
        in
          H.div [ H.classes [ "group", "flex", "items-start", "gap-2", "border-b", "border-neutral-100", "p-2", "dark:border-neutral-800" ], attr "style" "max-height:120px; overflow-y:auto;" ]
            [ H.div [ H.classes [ "flex", "min-w-0", "flex-1", "items-start", "gap-1.5" ] ]
                [ H.span [ H.classes [ "select-none", "font-semibold", "text-neutral-400" ] ] [ H.text "$" ]
                , cmdCode cmd
                ]
            , H.div [ H.classes [ "flex", "shrink-0", "items-start" ] ]
                [ unsafeRawHtml (BBH.renderCopyButtonHtml cmd) ]
            ]
      else
        H.div [ H.classes [ "border-b", "border-neutral-100", "p-2", "dark:border-neutral-800" ], attr "style" "max-height:140px; overflow-y:auto;" ]
          (map cmdRow cmdLines)
    outputSection =
      if String.trim p.output == "" then
        []
      else
        [ H.div [ H.classes [ "overflow-x-auto" ] ]
            [ H.pre
                [ H.classes [ "m-0", "min-w-full", "whitespace-pre", "px-2", "py-2", "font-mono", "text-[13px]", "leading-6", "text-neutral-600", "dark:text-neutral-300" ]
                , attr "style" "max-height:400px; overflow:auto;"
                , prop "innerHTML" (BBH.escapeHtml p.output)
                ]
                []
            ]
        ]
  in
    H.div
      [ attr "data-component" "tool-display-card"
      , attr "data-block-id" p.id
      , H.classes [ "terminal-card", "not-prose", "my-2", "overflow-hidden", "rounded-lg", "border", "border-neutral-200", "bg-neutral-50", "dark:border-neutral-700", "dark:bg-neutral-950" ]
      ]
      [ H.button
          [ attr "type" "button"
          , onClick (always_ toggleAct)
          , attr "aria-expanded" (if expanded then "true" else "false")
          , attr "aria-controls" bodyElId
          , H.classes
              [ "flex", "w-full", "items-center", "justify-start", "gap-2", "border-b", "border-neutral-200", "bg-neutral-100", "px-2", "py-1", "text-left", "text-[12px]", "text-neutral-600", "hover:text-neutral-800", "dark:border-neutral-700", "dark:bg-neutral-900", "dark:text-neutral-300", "dark:hover:text-neutral-100"
              ]
          ]
          [ H.span [ H.classes [ "flex", "h-5", "w-3", "min-w-3", "items-center", "justify-center", "text-neutral-400" ], attr "aria-hidden" "true" ]
              [ unsafeRawHtml "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"12\" height=\"12\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.25\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"terminal-chevron\" aria-hidden=\"true\"><path d=\"m9 18 6-6-6-6\"></path></svg>"
              ]
          , H.span [ H.classes [ "min-w-0", "flex-1", "truncate", "font-medium" ] ] [ H.text titleTxt ]
          ]
      , commandSection
      , H.div [ H.id_ bodyElId, H.hidden (not expanded) ] outputSection
      ]
