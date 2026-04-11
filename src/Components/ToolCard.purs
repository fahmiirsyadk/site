module Components.ToolCard (toolCard, toolDisplayIslandCard) where

import Prelude

import BodyBlockHtml as BBH
import Data.Array (catMaybes)
import Data.Maybe (Maybe(..))
import Luna.Html (Html, attr, unsafeRawHtml)
import Luna.Html as H
import Luna.Html.Events (always_, onClick)
import Types (ToolCardState)

toolDisplayIslandCard
  :: forall i
   . ToolCardState
  -> (String -> i)
  -> { id :: String
     , file :: String
     , addStat :: Maybe String
     , delStat :: Maybe String
     , bodyInnerHtml :: String
     , expandSrOnly :: String
     }
  -> Html i
toolDisplayIslandCard state onToggle r =
  let
    rootClasses =
      catMaybes
        [ Just "not-prose"
        , Just "my-2"
        , Just "overflow-hidden"
        , Just "rounded-lg"
        , Just "border"
        , Just "border-neutral-200"
        , Just "bg-neutral-50"
        , Just "dark:border-neutral-700"
        , Just "dark:bg-neutral-950"
        , if not state.needsExpand then Just "tool-display-card--no-expand" else Nothing
        , if state.needsExpand && state.expanded then Just "is-expanded" else Nothing
        ]
    expandOpen = state.expanded
    btnCls =
      [ "tool-display-expand-btn"
      , "flex"
      , "h-8"
      , "w-full"
      , "cursor-pointer"
      , "items-center"
      , "justify-center"
      , "border-t"
      , "border-neutral-100"
      , "text-neutral-400"
      , "transition-colors"
      , "hover:bg-neutral-50"
      , "hover:text-neutral-600"
      , "dark:border-neutral-800"
      , "dark:hover:bg-neutral-800"
      , "dark:hover:text-neutral-300"
      ]
  in
    H.div
      [ attr "data-component" "tool-display-card"
      , attr "data-block-id" r.id
      , attr "data-measured-island" "true"
      , H.classes rootClasses
      ]
      [ H.div
          [ H.classes [ "flex", "items-center", "justify-between", "gap-2", "border-b", "border-neutral-200", "bg-neutral-100", "px-2", "dark:border-neutral-700", "dark:bg-neutral-900" ] ]
          [ H.div [ H.classes [ "flex", "min-h-7", "min-w-0", "flex-1", "items-center", "gap-2", "py-1" ] ]
              [ H.span [ H.classes [ "truncate", "text-[12px]", "font-medium", "text-neutral-800", "dark:text-neutral-200" ] ] [ H.text r.file ]
              ]
          , unsafeRawHtml (BBH.toolDisplayStatsInnerHtml r.addStat r.delStat)
          ]
      , H.div
          [ H.classes [ "tool-display-body", "relative", "min-h-0", "bg-neutral-50", "dark:bg-neutral-900" ] ]
          [ unsafeRawHtml r.bodyInnerHtml ]
      , if state.needsExpand then
          H.button
            [ attr "type" "button"
            , onClick (always_ (onToggle r.id))
            , attr "aria-expanded" (if expandOpen then "true" else "false")
            , attr "aria-label" r.expandSrOnly
            , H.classes btnCls
            ]
            [ H.span [ H.classes [ "sr-only" ] ] [ H.text r.expandSrOnly ]
            , unsafeRawHtml "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"tool-display-chevron h-3.5 w-3.5 shrink-0\" aria-hidden=\"true\"><path d=\"m6 9 6 6 6-6\"></path></svg>"
            ]
        else
          H.text ""
      ]

toolCard
  :: forall i
   . ToolCardState
  -> (String -> i)
  -> { id :: String, file :: String, addStat :: Maybe String, delStat :: Maybe String, content :: String }
  -> Html i
toolCard state onToggle r =
  toolDisplayIslandCard state onToggle
    { id: r.id
    , file: r.file
    , addStat: r.addStat
    , delStat: r.delStat
    , bodyInnerHtml: BBH.renderToolCardBodyHtml r.content
    , expandSrOnly: "Expand code block"
    }
