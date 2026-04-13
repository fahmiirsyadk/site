module App where

import Prelude

import Components.Footer (footer)
import Components.LeftRail (desktopMainChrome, floatingToc, leftRail)
import Data.Array as Array
import GfxBoot (bootOverlay)
import Data.Const (Const)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Luna.App as LunaApp
import Luna.Html (Html, attr)
import Luna.Html as H
import Luna.Transition (Transition, purely)
import Pages.About as AboutPage
import Pages.Article as ArticlePage
import Pages.Home as HomePage
import Routes (parseRoutePath)
import Types (BodyBlock, Post, Route(..), SiteManifest, TocItem, ToolCardState, defaultToolCardState)

type Model =
  { route :: Route
  , manifest :: SiteManifest
  , activeTocId :: Maybe String
  , useRelativeDates :: Boolean
  , relativeTimeTick :: Int
  , themeMode :: String
  , terminalExpanded :: Map.Map String Boolean
  , toolCards :: Map.Map String ToolCardState
  }

data Action
  = RouteChanged (Maybe Route)
  | NavigatePath String
  | ReplaceManifest SiteManifest
  | MergePostContent
      { section :: String
      , slug :: String
      , bodyHtml :: String
      , bodyBlocks :: Array BodyBlock
      , toc :: Array TocItem
      }
  | TerminalToggle String
  | ToolToggle String
  | ToolCardMeasured String Int
  | SetActiveToc String
  | EnableRelativeDates
  | TickRelativeDates
  | SetThemeMode String

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
      Just route ->
        model
          { route = route
          , activeTocId = Nothing
          , terminalExpanded = Map.empty
          , toolCards = Map.empty
          }
  NavigatePath path ->
    purely case parseRoutePath path of
      Nothing -> model
      Just route ->
        model
          { route = route
          , activeTocId = Nothing
          , terminalExpanded = Map.empty
          , toolCards = Map.empty
          }
  ReplaceManifest manifest ->
    purely model { manifest = manifest }
  MergePostContent payload ->
    purely model
      { manifest = model.manifest
          { posts = map (mergeContent payload) model.manifest.posts
          }
      , toolCards = Map.empty
      }
  TerminalToggle id ->
    purely
      let
        cur = fromMaybe true $ Map.lookup id model.terminalExpanded
      in
        model { terminalExpanded = Map.insert id (not cur) model.terminalExpanded }
  ToolToggle id ->
    purely
      let
        st = fromMaybe defaultToolCardState $ Map.lookup id model.toolCards
      in
        if not st.needsExpand then
          model
        else
          model { toolCards = Map.insert id (st { expanded = not st.expanded }) model.toolCards }
  ToolCardMeasured id h ->
    purely
      let
        needs = h > 200
        prevMb = Map.lookup id model.toolCards
        expanded = case prevMb of
          Nothing -> true
          Just p -> if needs then p.expanded else false
      in
        model { toolCards = Map.insert id { expanded, needsExpand: needs } model.toolCards }
  SetActiveToc id ->
    purely model { activeTocId = if id == "" then Nothing else Just id }
  EnableRelativeDates ->
    purely model { useRelativeDates = true }
  TickRelativeDates ->
    purely
      if model.useRelativeDates then
        model { relativeTimeTick = model.relativeTimeTick + 1 }
      else
        model
  SetThemeMode raw ->
    purely model { themeMode = normalizeThemeMode raw }
  where
  mergeContent payload post =
    if post.section == payload.section && post.slug == payload.slug then
      post { bodyHtml = Just payload.bodyHtml, bodyBlocks = payload.bodyBlocks, toc = payload.toc }
    else
      post

normalizeThemeMode :: String -> String
normalizeThemeMode s =
  if s == "dark" then "dark" else "light"

render :: Model -> Html Action
render model =
  siteLayout model.route (currentToc model.manifest model.route) model.activeTocId model.themeMode SetThemeMode
    ( renderPage model.useRelativeDates model.manifest model.route model.terminalExpanded model.toolCards
    )

renderStatic :: SiteManifest -> Route -> Html Action
renderStatic manifest route =
  siteLayout route (currentToc manifest route) Nothing "light" SetThemeMode
    (renderPage false manifest route Map.empty Map.empty)

-- | Prerender / SSG `<body>`: `GfxBoot.bootOverlay` + `#app` (hydrate target) + async `gfx-boot.js`.
ssgBodyHtml :: forall i. String -> Html i -> Html i
ssgBodyHtml gfxBootBuildHash appInner =
  H.div
    [ H.classes [ "relative", "min-h-full" ] ]
    [ bootOverlay
    , H.div [ H.id_ "app" ] [ appInner ]
    , H.script
        [ H.src ("/gfx-boot.js?v=" <> gfxBootBuildHash)
        , attr "async" "async"
        ]
        []
    ]

renderPage :: Boolean -> SiteManifest -> Route -> Map.Map String Boolean -> Map.Map String ToolCardState -> Html Action
renderPage useRelativeDates manifest route termExp toolSt =
  case route of
    Home -> HomePage.view useRelativeDates manifest.posts
    About -> AboutPage.view
    SectionIndex section -> HomePage.view useRelativeDates (Array.filter (\p -> p.section == section) manifest.posts)
    SectionPost section slug ->
      ArticlePage.view termExp toolSt TerminalToggle ToolToggle slug section manifest.posts useRelativeDates

currentToc :: SiteManifest -> Route -> Array TocItem
currentToc manifest route = case route of
  SectionPost section slug -> maybe [] _.toc (findPostBySectionSlug manifest.posts section slug)
  _ -> []

findPostBySectionSlug :: Array Post -> String -> String -> Maybe Post
findPostBySectionSlug posts section slug =
  Array.find (\p -> p.slug == slug && p.section == section) posts

-- | Shared shell for client (`render`) and prerender (`renderStatic`). Static HTML passes no TOC
-- | highlight and default `"light"` theme; `Main.js` aligns theme controls with stored preference on boot.
siteLayout :: Route -> Array TocItem -> Maybe String -> String -> (String -> Action) -> Html Action -> Html Action
siteLayout current toc activeTocId themeMode onThemeMode pageContent =
  H.div
    [ H.classes [ "min-h-screen", "bg-[#F5F5F5]", "text-[#171717]", "antialiased", "dark:bg-neutral-950", "dark:text-neutral-100" ] ]
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
        [ leftRail current toc activeTocId themeMode onThemeMode
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
                , "dark:border-neutral-800"
                , "dark:bg-neutral-900"
                , "md:border-t-0"
                , "max-md:pt-[calc(5.5rem+env(safe-area-inset-top,0px))]"
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
                    , "bg-white"
                    , "dark:bg-neutral-900"
                    , "px-8"
                    , "pt-6"
                    , "max-md:pt-4"
                    , "md:pt-14"
                    , "pb-0"
                    ]
                , attr "id" "content-scroll"
                ]
                [ floatingToc current toc activeTocId
                , H.div
                    [ H.classes [ "w-full", "max-w-3xl", "text-left" ] ]
                    [ desktopMainChrome current themeMode onThemeMode
                    , pageContent
                    ]
                , footer
                ]
            ]
        ]
    ]