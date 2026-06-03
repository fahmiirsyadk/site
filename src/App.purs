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
import Types (BodyBlock, Route(..), Section, SiteManifest, ThemeMode(..), TocItem, ToolCardState, defaultToolCardState, findPost, sectionFrom, themeModeFrom, themeModeToString)

type Model =
  { route :: Route
  , manifest :: SiteManifest
  , activeTocId :: Maybe String
  , themeMode :: ThemeMode
  , terminalExpanded :: Map.Map String Boolean
  , toolCards :: Map.Map String ToolCardState
  }

data Action
  = RouteChanged (Maybe Route)
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
  | SetThemeMode ThemeMode

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
  SetThemeMode mode ->
    purely model { themeMode = mode }
  where
  mergeContent payload post =
    if post.section == sectionFrom payload.section && post.slug == payload.slug then
      post { bodyHtml = Just payload.bodyHtml, bodyBlocks = payload.bodyBlocks, toc = payload.toc }
    else
      post

-- Remove unused normalizeThemeMode

render :: Model -> Html Action
render model =
  siteLayout model.route (currentToc model.manifest model.route) model.activeTocId model.themeMode SetThemeMode
    ( renderPage model.manifest model.route model.terminalExpanded model.toolCards
    )

renderStatic :: SiteManifest -> Route -> Html Action
renderStatic manifest route =
  siteLayout route (currentToc manifest route) Nothing Light SetThemeMode
    (renderPage manifest route Map.empty Map.empty)

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

renderPage :: SiteManifest -> Route -> Map.Map String Boolean -> Map.Map String ToolCardState -> Html Action
renderPage manifest route termExp toolSt =
  case route of
    Home -> HomePage.view manifest.posts
    About -> AboutPage.view
    SectionIndex sectionStr -> HomePage.view (Array.filter (\p -> p.section == sectionFrom sectionStr) manifest.posts)
    SectionPost sectionStr slug ->
      ArticlePage.view termExp toolSt TerminalToggle ToolToggle slug sectionStr manifest.posts

currentToc :: SiteManifest -> Route -> Array TocItem
currentToc manifest route = case route of
  SectionPost sectionStr slug -> maybe [] _.toc (findPost manifest.posts (sectionFrom sectionStr) slug)
  _ -> []

-- | Shared shell for client (`render`) and prerender (`renderStatic`). Static HTML passes no TOC
-- | highlight and default `Light` theme; client aligns theme controls with stored preference on boot.
siteLayout :: Route -> Array TocItem -> Maybe String -> ThemeMode -> (ThemeMode -> Action) -> Html Action -> Html Action
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
