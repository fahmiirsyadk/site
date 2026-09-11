-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The home page: the introduction, the GitHub card, and the latest posts.
-- Ported from the source's @Page.Home@, @Component.GitHubCard@, and
-- @Component.PostList@.
module Site.View.Home
  ( homeView
  ) where
-----------------------------------------------------------------------------
import           Miso (text)
import           Miso.Event (onBeforeDestroyedWith, onCreatedWith)
import           Miso.Html.Element as H
import           Miso.Html.Property as P
import           Miso.Property (textProp)
import           Miso.String (ms)
import qualified Miso.Svg.Element as S
import qualified Miso.Svg.Property as SP
-----------------------------------------------------------------------------
import           Site.Action (Action (..), Element (..))
import qualified Site.Config as Config
import           Site.Content (Post)
import qualified Site.Content as Content
import           Site.GitHub (GitHubActivity (..), GitHubStatus (..))
import           Site.Route (Route (..))
import           Site.View.Icons (githubIcon, mailIcon)
import           Site.View.Link (Node, internalLink)
-----------------------------------------------------------------------------
homeView :: GitHubStatus -> Node context
homeView status =
  H.div_
    [ P.class_ "space-y-12" ]
    [ introduction status
    , latestPosts
    ]
-----------------------------------------------------------------------------
introduction :: GitHubStatus -> Node context
introduction status =
  H.section_
    [ P.class_ "w-full" ]
    [ H.div_
        [ P.class_ "space-y-3 text-[13px] leading-[1.7] text-ink dark:text-neutral-200" ]
        [ H.p_ []
            [ text "Frontend engineer from Indonesia. I build interfaces and developer tools, with equal interest in how software feels and how it works." ]
        , H.p_ []
            [ text "This is where I share what I’m building, learning, and "
            , thinkingAbout
            , text " through projects, experiments, and notes on software."
            ]
        , H.p_ []
            [ text "Find me on "
            , gitHubCard status
            , H.span_ [ P.class_ "mx-1 text-coral" ] [ text "↗" ]
            , text " or email "
            , H.a_
                [ P.href_ ("mailto:" <> Config.emailAddress)
                , P.class_ "inline-flex items-center gap-1 underline decoration-dotted decoration-neutral-400 underline-offset-4 hover:text-coral"
                ]
                [ mailIcon, text Config.emailAddress ]
            , text "."
            ]
        ]
    ]
-----------------------------------------------------------------------------
-- | The scribble around "thinking about". The path starts hidden and the
-- widget stages and animates one variant at a time.
thinkingAbout :: Node context
thinkingAbout =
  H.span_
    [ P.data_ Config.scribbleKey "true"
    , P.class_ "thinking-scribble"
    , onCreatedWith (ScribbleMounted . Element)
    , onBeforeDestroyedWith (ScribbleDisposed . Element)
    ]
    [ H.span_ [ P.class_ "thinking-scribble-text" ] [ text "thinking about" ]
    , S.svg_
        [ P.aria_ "hidden" "true"
        , SP.viewBox_ "0 0 132 72"
        , P.class_ "thinking-scribble-svg"
        ]
        [ S.path_
            [ P.data_ Config.scribblePathKey "true"
            , SP.d_ "M8 38Q12 8 43 12 76 16 57 45 38 70 20 48 0 24 47 6 92-4 111 25 128 52 83 51 35 49 61 13 84-12 105 36 118 72 68 61 17 50 31 17 41-8 79 17 112 38 75 66 35 82 14 43-2 13 49 20 103 27 88 55 73 78 42 47 12 17 55 5 98-5 119 31 129 60 82 42 37 24 47 59 55 79 91 53 122 32 97 14 71-4 28 31 5 54 52 67 100 76 109 38 116 6 66 25 22 43 41 8 62-10 89 30 108 58 65 55 26 52 21 31 17 9 60 16 104 22 93 48 80 70 48 40 22 15 71 7 116 1 119 39 120 68 72 48 29 31 8 38"
            , SP.stroke_ "currentColor"
            , SP.strokeWidth_ "5.5"
            , SP.strokeLinecap_ "round"
            , SP.strokeLinejoin_ "round"
            , P.class_ "thinking-scribble-path"
            ]
        ]
    ]
-----------------------------------------------------------------------------
latestPosts :: Node context
latestPosts =
  H.section_
    [ P.class_ "space-y-6" ]
    [ H.p_ [ P.class_ "text-[12px] text-neutral-500" ] [ text "Latest posts" ]
    , if null posts
        then H.p_ [ P.class_ "text-[12px] text-neutral-500" ] [ text "No posts yet." ]
        else H.div_ [ P.class_ "flex w-full flex-col" ] (map postPreview posts)
    ]
  where
    posts = Content.publishedPosts
-----------------------------------------------------------------------------
postPreview :: Post -> Node context
postPreview post =
  internalLink (Post (Content.postSection post) (Content.postSlug post))
    [ P.class_ "post-row group flex w-full items-center gap-3 py-2 text-[12px] leading-[1.7] no-underline" ]
    [ H.span_
        [ P.class_ "min-w-0 font-instrument text-[16px] leading-[1.3] text-ink transition-colors group-hover:text-coral dark:text-neutral-200 dark:group-hover:text-coral-bright" ]
        [ text (Content.postTitle post) ]
    , H.span_ [ P.class_ "min-h-px min-w-6 flex-1 border-b border-neutral-300 dark:border-neutral-600" ] []
    , H.span_
        [ P.class_ "shrink-0 whitespace-nowrap text-right text-neutral-600 dark:text-neutral-400 max-sm:hidden" ]
        [ text (Content.postDateLabel post) ]
    ]
-----------------------------------------------------------------------------
gitHubCard :: GitHubStatus -> Node context
gitHubCard status =
  H.span_
    [ P.class_ "github-preview group/github relative inline-block" ]
    [ H.a_
        [ P.href_ Config.githubProfileUrl
        , P.target_ "_blank"
        , P.rel_ "noreferrer"
        , P.class_ "underline decoration-dotted decoration-neutral-400 underline-offset-4 hover:text-coral"
        ]
        [ githubIcon
        , H.span_ [ P.class_ "ml-1" ] [ text "GitHub" ]
        ]
    , H.span_
        -- The centering comes from the .github-preview-card transform rules,
        -- not a translate utility: Tailwind v4 compiles those to the
        -- `translate` property, which would stack with the rule.
        [ P.class_ "github-preview-card pointer-events-none absolute bottom-[calc(100%+0.6rem)] left-1/2 z-30 w-52 rounded-md border border-neutral-200 bg-white p-3 text-left opacity-0 shadow-lg transition duration-200 group-hover/github:pointer-events-auto group-hover/github:opacity-100 group-focus-within/github:pointer-events-auto group-focus-within/github:opacity-100 dark:border-neutral-700 dark:bg-neutral-900" ]
        [ H.span_
            [ P.class_ "flex items-center gap-2.5" ]
            [ H.img_
                [ P.src_ Config.githubAvatarUrl
                , textProp "alt" ""
                , P.class_ "h-8 w-8 rounded-full"
                ]
            , H.span_
                [ P.class_ "flex min-w-0 flex-col leading-tight" ]
                [ H.strong_
                    [ P.class_ "text-[12px] text-ink dark:text-neutral-100" ]
                    [ text Config.githubDisplayName ]
                , H.span_
                    [ P.class_ "text-[10px] text-neutral-400" ]
                    [ text ("@" <> Config.githubUsername <> " · " <> Config.githubLocation) ]
                ]
            ]
        , activity status
        ]
    ]
-----------------------------------------------------------------------------
activity :: GitHubStatus -> Node context
activity = \case
  GitHubLoading ->
    H.span_
      [ P.class_ "mt-3 block h-14 w-full animate-pulse rounded-sm bg-neutral-100 dark:bg-neutral-800" ]
      []
  GitHubFailed ->
    H.span_
      [ P.class_ "mt-3 block text-[10px] text-neutral-400" ]
      [ text "GitHub activity is unavailable." ]
  GitHubReady ready ->
    H.span_
      []
      [ H.span_
          [ P.class_ "github-contribution-grid mt-3 grid w-full grid-flow-col grid-rows-4 gap-[2px]" ]
          (map levelCell (activityLevels ready))
      , H.span_
          [ P.class_ "mt-2 flex items-center gap-1.5 text-[10px] text-neutral-400" ]
          [ H.span_
              []
              [ H.strong_
                  [ P.class_ "font-semibold text-neutral-600 dark:text-neutral-300" ]
                  [ text (ms (activityContributions ready)) ]
              , text " contributions"
              ]
          , H.span_ [ P.aria_ "hidden" "true" ] [ text "·" ]
          , H.span_
              []
              [ H.strong_
                  [ P.class_ "font-semibold text-neutral-600 dark:text-neutral-300" ]
                  [ text (ms (activityFollowers ready)) ]
              , text " followers"
              ]
          ]
      ]
  where
    levelCell level =
      H.i_
        [ P.data_ "level" (ms level)
        , P.class_ "github-contribution block aspect-square w-full rounded-[1px]"
        ]
        []
