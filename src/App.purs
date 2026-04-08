module App where

import Prelude

import Components.Footer (footer)
import Components.LeftRail (leftRail)
import Data.Array as Array
import Data.Const (Const)
import Data.Maybe (Maybe(..), maybe)
import Luna.App as LunaApp
import Luna.Html (Html, attr)
import Luna.Html as H
import Luna.Transition (Transition, purely)
import Pages.About as AboutPage
import Pages.Article as ArticlePage
import Pages.Collection as CollectionPage
import Pages.Home as HomePage
import Pages.Project as ProjectPage
import Routes (parseRoutePath)
import Types (Post, Route(..), SiteManifest, TocItem)

type Model =
  { route :: Route
  , manifest :: SiteManifest
  , activeTocId :: Maybe String
  }

data Action
  = RouteChanged (Maybe Route)
  | NavigatePath String
  | SetActiveToc String

app :: Model -> LunaApp.App (Const Void) (Const Void) Model Action
app initialModel =
  { render
  , update
  , subs: const mempty
  , init: purely initialModel
  }

update :: Model -> Action -> Transition (Const Void) Model Action
update model = case _ of
  RouteChanged maybeRoute ->
    purely case maybeRoute of
      Nothing -> model
      Just route -> model { route = route, activeTocId = Nothing }
  NavigatePath path ->
    purely case parseRoutePath path of
      Nothing -> model
      Just route -> model { route = route, activeTocId = Nothing }
  SetActiveToc id ->
    purely model { activeTocId = Just id }

render :: Model -> Html Action
render model =
  siteLayout model.route (currentToc model.manifest model.route) model.activeTocId (Just SetActiveToc) (renderPage model.manifest model.route)

renderStatic :: forall i. SiteManifest -> Route -> Html i
renderStatic manifest route =
  siteLayoutStatic route (currentToc manifest route) (renderPage manifest route)

renderPage :: forall i. SiteManifest -> Route -> Html i
renderPage manifest route =
  case route of
    Home -> HomePage.view manifest.posts
    About -> AboutPage.view
    ArticlesIndex -> HomePage.view manifest.articles
    ProjectsIndex -> HomePage.view manifest.projects
    Article slug -> ArticlePage.view slug manifest.posts
    Project slug -> ProjectPage.view slug manifest.posts
    Collection tag -> CollectionPage.view tag manifest.posts

currentToc :: SiteManifest -> Route -> Array TocItem
currentToc manifest route = case route of
  Article slug -> maybe [] _.toc (findPostBySlug manifest.posts slug)
  Project slug -> maybe [] _.toc (findPostBySlug manifest.posts slug)
  _ -> []

findPostBySlug :: Array Post -> String -> Maybe Post
findPostBySlug posts slug =
  Array.find (\p -> p.slug == slug) posts

siteLayout :: Route -> Array TocItem -> Maybe String -> Maybe (String -> Action) -> Html Action -> Html Action
siteLayout current toc activeTocId onTocSelect pageContent =
  H.div
    [ H.classes [ "min-h-screen", "bg-[#F5F5F5]", "text-[#171717]", "antialiased" ] ]
    [ H.div
        [ H.classes
            [ "flex"
            , "min-h-screen"
            , "w-full"
            , "flex-col"
            , "md:h-screen"
            , "md:max-h-screen"
            , "md:flex-row"
            , "md:overflow-hidden"
            ]
        ]
        [ leftRail current toc activeTocId onTocSelect
        , H.main
            [ H.classes
                [ "flex"
                , "h-full"
                , "min-h-0"
                , "min-w-0"
                , "flex-1"
                , "flex-col"
                , "border-t"
                , "border-[#E5E5E5]"
                , "bg-white"
                , "md:border-t-0"
                ]
            ]
            [ H.div
                [ H.classes
                    [ "flex"
                    , "h-full"
                    , "min-h-0"
                    , "overflow-y-auto"
                    , "min-h-full"
                    , "w-full"
                    , "flex-1"
                    , "flex-col"
                    , "items-center"
                    , "justify-start"
                    , "px-8"
                    , "py-14"
                    ]
                , attr "id" "content-scroll"
                ]
                [ H.div
                    [ H.classes [ "w-full", "max-w-3xl", "text-left" ] ]
                    [ pageContent, footer ]
                ]
            ]
        ]
    ]

siteLayoutStatic :: forall i. Route -> Array TocItem -> Html i -> Html i
siteLayoutStatic current toc pageContent =
  H.div
    [ H.classes [ "min-h-screen", "bg-[#F5F5F5]", "text-[#171717]", "antialiased" ] ]
    [ H.div
        [ H.classes
            [ "flex"
            , "min-h-screen"
            , "w-full"
            , "flex-col"
            , "md:h-screen"
            , "md:max-h-screen"
            , "md:flex-row"
            , "md:overflow-hidden"
            ]
        ]
        [ leftRail current toc Nothing Nothing
        , H.main
            [ H.classes
                [ "flex"
                , "h-full"
                , "min-h-0"
                , "min-w-0"
                , "flex-1"
                , "flex-col"
                , "border-t"
                , "border-[#E5E5E5]"
                , "bg-white"
                , "md:border-t-0"
                ]
            ]
            [ H.div
                [ H.classes
                    [ "flex"
                    , "h-full"
                    , "min-h-0"
                    , "overflow-y-auto"
                    , "min-h-full"
                    , "w-full"
                    , "flex-1"
                    , "flex-col"
                    , "items-center"
                    , "justify-start"
                    , "px-8"
                    , "py-14"
                    ]
                , attr "id" "content-scroll"
                ]
                [ H.div
                    [ H.classes [ "w-full", "max-w-3xl", "text-left" ] ]
                    [ pageContent, footer ]
                ]
            ]
        ]
    ]