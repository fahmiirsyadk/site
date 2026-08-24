module Component.GitHubCard where

import Prelude

import Component.Icon as Icon
import Data.Array as Array
import App.Site as Site
import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Prop as HP
import Page.Home.Model as Home

view :: forall message. Home.Status -> FK.Child message
view status =
  HH.span [ HP.class_ "github-preview group/github relative inline-block" ]
    [ HH.a
        [ HP.attr "href" Site.githubProfileUrl
        , HP.attr "target" "_blank"
        , HP.attr "rel" "noreferrer"
        , HP.class_ "underline decoration-dotted decoration-neutral-400 underline-offset-4 hover:text-[#FF4B26]"
        ]
        [ Icon.github
        , HH.span [ HP.class_ "ml-1" ] [ HH.text "GitHub" ]
        ]
    , HH.span
        [ HP.class_ "github-preview-card pointer-events-none absolute bottom-[calc(100%+0.6rem)] left-1/2 z-30 w-52 -translate-x-1/2 rounded-md border border-neutral-200 bg-white p-3 text-left opacity-0 shadow-lg transition duration-200 group-hover/github:pointer-events-auto group-hover/github:translate-y-0 group-hover/github:opacity-100 group-focus-within/github:pointer-events-auto group-focus-within/github:translate-y-0 group-focus-within/github:opacity-100 dark:border-neutral-700 dark:bg-neutral-900"
        ]
        [ HH.span [ HP.class_ "flex items-center gap-2.5" ]
            [ HH.img
                [ HP.attr "src" Site.githubAvatarUrl
                , HP.attr "alt" ""
                , HP.class_ "h-8 w-8 rounded-full"
                ] []
            , HH.span [ HP.class_ "flex min-w-0 flex-col leading-tight" ]
                [ HH.strong [ HP.class_ "text-[12px] text-[#171717] dark:text-neutral-100" ] [ HH.text Site.githubDisplayName ]
                , HH.span [ HP.class_ "text-[10px] text-neutral-400" ] [ HH.text ("@" <> Site.githubUsername <> " · " <> Site.githubLocation) ]
                ]
            ]
        , activity status
        ]
    ]

activity :: forall message. Home.Status -> FK.Child message
activity status = case status of
  Home.Loading ->
    HH.span [ HP.class_ "mt-3 block h-14 w-full animate-pulse rounded-sm bg-neutral-100 dark:bg-neutral-800" ] []
  Home.Failed ->
    HH.span [ HP.class_ "mt-3 block text-[10px] text-neutral-400" ] [ HH.text "GitHub activity is unavailable." ]
  Home.Ready github ->
    HH.span []
      [ HH.span [ HP.class_ "github-contribution-grid mt-3 grid w-full grid-flow-col grid-rows-4 gap-[2px]" ]
          (Array.mapWithIndex
            (\index level -> HH.keyed "i" (show index)
              [ HP.attr "data-level" (show level)
              , HP.class_ "github-contribution block aspect-square w-full rounded-[1px]"
              ] [])
            github.levels)
      , HH.span [ HP.class_ "mt-2 flex items-center gap-1.5 text-[10px] text-neutral-400" ]
          [ HH.span [] [ HH.strong [ HP.class_ "font-semibold text-neutral-600 dark:text-neutral-300" ] [ HH.text (show github.contributions) ], HH.text " contributions" ]
          , HH.span [ HP.attr "aria-hidden" "true" ] [ HH.text "·" ]
          , HH.span [] [ HH.strong [ HP.class_ "font-semibold text-neutral-600 dark:text-neutral-300" ] [ HH.text (show github.followers) ], HH.text " followers" ]
          ]
      ]
