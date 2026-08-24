module Page.Home where

import Prelude

import Component.GitHubCard as GitHubCard
import Component.Icon as Icon
import Component.PostList as PostList
import App.Site as Site
import Page.Home.Model as HomeModel
import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Mount (MountAction)
import Interop.Foldkit.Prop as HP

type Post =
  { slug :: String
  , path :: String
  , title :: String
  , date :: String
  , dateLabel :: String
  }

type Input message =
  { githubStatus :: HomeModel.Status
  , posts :: Array Post
  , scribbleMount :: MountAction message
  }

postPreview :: forall message. Post -> FK.Child message
postPreview post =
  HH.keyed "a" post.slug
    [ HP.attr "href" post.path
    , HP.class_ "post-row group flex w-full items-center gap-3 py-2 text-[12px] leading-[1.7] no-underline"
    ]
    [ HH.span [ HP.class_ "min-w-0 font-instrument text-[16px] leading-[1.3] text-[#171717] transition-colors group-hover:text-[#FF4B26] dark:text-neutral-200 dark:group-hover:text-[#FF6B4A]" ] [ HH.text post.title ]
    , HH.span [ HP.class_ "min-h-px min-w-6 flex-1 border-b border-neutral-300 dark:border-neutral-600" ] []
    , HH.span [ HP.attr "data-relative-date" post.date, HP.class_ "shrink-0 whitespace-nowrap text-right text-neutral-500 max-sm:hidden" ] [ HH.text post.dateLabel ]
    ]

thinkingAbout :: forall message. MountAction message -> FK.Child message
thinkingAbout mount =
  HH.span
    [ HP.attr "data-random-scribble" "true"
    , HP.class_ "thinking-scribble"
    , HP.onMount { action: mount }
    ]
    [ HH.span [ HP.class_ "thinking-scribble-text" ] [ HH.text "thinking about" ]
    , HH.svg
        [ HP.attr "aria-hidden" "true"
        , HP.attr "viewBox" "0 0 132 72"
        , HP.class_ "thinking-scribble-svg"
        ]
        [ HH.path
            [ HP.attr "data-random-scribble-path" "true"
            , HP.attr "d" "M8 38Q12 8 43 12 76 16 57 45 38 70 20 48 0 24 47 6 92-4 111 25 128 52 83 51 35 49 61 13 84-12 105 36 118 72 68 61 17 50 31 17 41-8 79 17 112 38 75 66 35 82 14 43-2 13 49 20 103 27 88 55 73 78 42 47 12 17 55 5 98-5 119 31 129 60 82 42 37 24 47 59 55 79 91 53 122 32 97 14 71-4 28 31 5 54 52 67 100 76 109 38 116 6 66 25 22 43 41 8 62-10 89 30 108 58 65 55 26 52 21 31 17 9 60 16 104 22 93 48 80 70 48 40 22 15 71 7 116 1 119 39 120 68 72 48 29 31 8 38"
            , HP.attr "stroke" "currentColor"
            , HP.attr "stroke-width" "5.5"
            , HP.attr "stroke-linecap" "round"
            , HP.attr "stroke-linejoin" "round"
            , HP.class_ "thinking-scribble-path"
            ] []
        ]
    ]

introduction :: forall message. Input message -> FK.Child message
introduction input =
  HH.section [ HP.class_ "w-full" ]
    [ HH.div [ HP.class_ "max-w-[32rem] space-y-3 text-[13px] leading-[1.7] text-[#171717] dark:text-neutral-200" ]
        [ HH.p [] [ HH.text "Frontend engineer from Indonesia. I build interfaces and developer tools, with equal interest in how software feels and how it works." ]
        , HH.p []
            [ HH.text "This is where I share what I’m building, learning, and "
            , thinkingAbout input.scribbleMount
            , HH.text " through projects, experiments, and notes on software."
            ]
        , HH.p []
            [ HH.text "Find me on "
            , GitHubCard.view input.githubStatus
            , HH.span [ HP.class_ "mx-1 text-[#FF4B26]" ] [ HH.text "↗" ]
            , HH.text " or email "
            , HH.a [ HP.attr "href" ("mailto:" <> Site.emailAddress), HP.class_ "inline-flex items-center gap-1 underline decoration-dotted decoration-neutral-400 underline-offset-4 hover:text-[#FF4B26]" ] [ Icon.mail, HH.text Site.emailAddress ]
            , HH.text "."
            ]
        ]
    ]

latestPosts :: forall message. Array Post -> FK.Child message
latestPosts posts =
  PostList.view
    { posts
    , emptyLabel: "Latest posts"
    , emptyText: "No posts yet."
    , render: postPreview
    }

view :: forall message. Input message -> FK.Child message
view input =
  HH.div [ HP.class_ "space-y-12" ]
    [ introduction input
    , latestPosts input.posts
    ]
