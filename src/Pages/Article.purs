module Pages.Article where

import Prelude

import BodyBlockHtml as BBH
import Components.DiffCard (diffCard)
import Components.TerminalCard (terminalCard)
import Components.ToolCard (toolCard)
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import RelativeTime (postDateLabel)
import Luna.Html (Html, attr, unsafeRawHtml)
import Luna.Html as H
import Routes (printRoutePath)
import Types (BodyBlock(..), Post, Route(..), ToolCardState, defaultToolCardState)

view
  :: forall i
   . Map.Map String Boolean
  -> Map.Map String ToolCardState
  -> (String -> i)
  -> (String -> i)
  -> String
  -> String
  -> Array Post
  -> Boolean
  -> Html i
view termExpanded toolCards onTerminalToggle onToolToggle slug section posts useRelativeDates =
  case Array.find (\p -> p.slug == slug && p.section == section) posts of
    Nothing ->
      H.div [ H.classes [ "space-y-3" ] ]
        [ H.h1 [ H.classes [ "text-[12px]", "leading-[1.7]", "font-semibold", "text-[#171717]", "dark:text-neutral-100" ] ] [ H.text "Article not found" ] ]
    Just p ->
      let
        sectionPosts = Array.filter (\post -> post.section == section) posts
        currentIndex = Array.findIndex (\post -> post.slug == slug) sectionPosts
        previousPost = case currentIndex of
          Just i -> Array.index sectionPosts (i + 1)
          Nothing -> Nothing
        nextPost = case currentIndex of
          Just i -> if i > 0 then Array.index sectionPosts (i - 1) else Nothing
          Nothing -> Nothing

        renderBlock :: BodyBlock -> Html i
        renderBlock (BodyTerminal t) =
          terminalCard
            (fromMaybe true $ Map.lookup t.id termExpanded)
            (onTerminalToggle t.id)
            t
        renderBlock (BodyToolCard r) =
          toolCard
            (fromMaybe defaultToolCardState $ Map.lookup r.id toolCards)
            onToolToggle
            r
        renderBlock (BodyDiffCard r) =
          diffCard
            (fromMaybe defaultToolCardState $ Map.lookup r.id toolCards)
            onToolToggle
            r
        renderBlock b =
          unsafeRawHtml (BBH.renderBodyBlock b)

        articleInner =
          if Array.null p.bodyBlocks then
            [ H.div
                [ H.classes
                    [ "rounded-lg"
                    , "border"
                    , "border-dashed"
                    , "border-neutral-300"
                    , "dark:border-neutral-600"
                    , "px-4"
                    , "py-14"
                    , "text-center"
                    , "text-neutral-500"
                    , "dark:text-neutral-400"
                    ]
                ]
                [ H.p [ H.classes [ "m-0", "text-[12px]", "leading-[1.7]" ] ] [ H.text "Loading article body…" ] ]
            ]
          else
            map renderBlock p.bodyBlocks
      in
        H.article [ H.classes [ "min-w-0", "space-y-6", "overflow-x-auto" ] ]
          [ H.div
              [ H.classes [ "flex", "w-full", "items-center", "gap-3", "text-[12px]", "leading-[1.7]" ] ]
              [ H.h1 [ H.classes [ "shrink-0", "font-instrument", "text-xl", "leading-tight", "text-[#171717]", "dark:text-neutral-100" ] ] [ H.text p.title ]
              , H.span
                  [ H.classes [ "min-h-px", "min-w-[1.5rem]", "flex-1", "border-b", "border-solid", "border-neutral-300", "dark:border-neutral-600" ] ]
                  []
              , H.span [ H.classes [ "shrink-0", "text-right", "text-neutral-500" ] ] [ H.text (postDateLabel useRelativeDates p.date) ]
              ]
          , H.div
              [ H.classes [ "flex", "h-48", "w-full", "items-center", "justify-center", "overflow-hidden" ] ]
              [ H.canvas
                  [ H.id_ "article-banner-canvas"
                  , attr "aria-label" (p.title <> " banner")
                  , H.classes [ "block", "h-full", "w-full" ]
                  , attr "style" "display:block;width:100%;height:192px;"
                  ]
              ]
          , H.div
              [ H.classes
                  [ "prose"
                  , "prose-neutral"
                  , "dark:prose-invert"
                  , "max-w-none"
                  , "prose-sm"
                  , "prose-headings:text-[#171717]"
                  , "dark:prose-headings:text-neutral-100"
                  , "prose-p:text-neutral-700"
                  , "dark:prose-p:text-neutral-300"
                  , "prose-li:text-neutral-700"
                  , "dark:prose-li:text-neutral-300"
                  , "prose-ul:list-none"
                  , "prose-ol:list-none"
                  , "prose-ul:pl-0"
                  , "prose-ol:pl-0"
                  , "prose-strong:text-[#171717]"
                  , "prose-a:text-[#FF4B26]"
                  , "prose-a:decoration-[#FF4B26]/40"
                  , "prose-img:max-w-full"
                  , "prose-img:h-auto"
                  , "prose-video:max-w-full"
                  , "prose-video:h-auto"
                  , "prose-canvas:max-w-full"
                  , "prose-canvas:h-auto"
                  , "prose-pre:max-w-full"
                  , "prose-pre:overflow-x-auto"
                  ]
              ]
              articleInner
          , if previousPost == Nothing && nextPost == Nothing then
              H.text ""
            else
              H.nav
                [ H.classes [ "mt-10", "border-t", "border-[#E5E5E5]", "pt-4", "text-[12px]", "leading-[1.7]", "dark:border-neutral-700" ] ]
                [ H.div [ H.classes [ "grid", "grid-cols-1", "gap-3", "md:grid-cols-2", "md:gap-6" ] ]
                    [ case previousPost of
                        Nothing ->
                          H.div [ H.classes [ "min-h-[2.5rem]" ] ] []
                        Just prev ->
                          H.a
                            [ H.href (printRoutePath (SectionPost prev.section prev.slug))
                            , H.classes
                                [ "flex"
                                , "flex-col"
                                , "gap-0.5"
                                , "no-underline"
                                , "text-[#171717]"
                                , "hover:text-[#FF4B26]"
                                , "dark:text-neutral-200"
                                , "dark:hover:text-[#FF6B4A]"
                                ]
                            ]
                            [ H.span [ H.classes [ "text-neutral-500", "dark:text-neutral-400" ] ] [ H.text "Previous article" ]
                            , H.span [ H.classes [ "font-medium", "dark:text-neutral-100" ] ] [ H.text ("<- " <> prev.title) ]
                            ]
                    , case nextPost of
                        Nothing ->
                          H.div [ H.classes [ "min-h-[2.5rem]" ] ] []
                        Just nxt ->
                          H.a
                            [ H.href (printRoutePath (SectionPost nxt.section nxt.slug))
                            , H.classes
                                [ "flex"
                                , "flex-col"
                                , "items-start"
                                , "gap-0.5"
                                , "no-underline"
                                , "text-[#171717]"
                                , "hover:text-[#FF4B26]"
                                , "dark:text-neutral-200"
                                , "dark:hover:text-[#FF6B4A]"
                                , "md:items-end"
                                , "md:text-right"
                                ]
                            ]
                            [ H.span [ H.classes [ "text-neutral-500", "dark:text-neutral-400" ] ] [ H.text "Next article" ]
                            , H.span [ H.classes [ "font-medium", "dark:text-neutral-100" ] ] [ H.text (nxt.title <> " ->") ]
                            ]
                    ]
                ]
          ]
