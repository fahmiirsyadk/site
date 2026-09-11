-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The shell: chrome that every page sits inside, and the dispatch to the
-- page itself.
--
-- __This module must stay free of effects.__ The prerender generator is a
-- native binary that evaluates 'viewModel' and serialises the result with
-- 'Miso.Html.Render.toHtml'. Native builds have no JavaScript, so any FFI
-- reached from here would be bottom at generation time. Effects belong in
-- 'Site.Platform' and the widget modules, called from 'Site.Update'.
module Site.View
  ( viewModel
    -- * Pieces
  , siteHeader
  , pageContent
  ) where
-----------------------------------------------------------------------------
import           Miso (text)
import           Miso.Event
  ( Phase (CAPTURE)
  , defaultOptions
  , emptyDecoder
  , onBeforeDestroyed
  , onCreated
  , onWithOptions
  )
import           Miso.Html.Element as H
import           Miso.Html.Event as E
import           Miso.Html.Property as P
import           Miso.Property (textProp)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.Action (Action (..))
import qualified Site.Config as Config
import qualified Site.Content as Content
import qualified Site.GitHub as GitHub
import           Site.Model (Model (..), Page (..))
import qualified Site.Model as Model
import           Site.Route (Route (..))
import qualified Site.Route as Route
import           Site.Theme (Theme (..))
import qualified Site.Theme as Theme
import           Site.View.Home (homeView)
import           Site.View.Icons (moonIcon, sunIcon)
import           Site.View.Link (Node, internalLink)
import           Site.View.Post (postView)
import           Site.View.Section (sectionView)
-----------------------------------------------------------------------------
viewModel :: context -> props -> Model -> Node context
viewModel _ _ model = applicationBody model
-----------------------------------------------------------------------------
-- | A missing page takes over the whole viewport rather than appearing inside
-- the usual column. The 404 is deliberately plain: no canvas, no world.
applicationBody :: Model -> Node context
applicationBody model =
  case _page model of
    NotFoundPage path -> notFoundBody path
    PostPage section slug -> case Content.findPost section slug of
      Nothing -> notFoundBody (Route.routePath (Post section slug))
      Just _  -> standardBody model
    _ -> standardBody model
-----------------------------------------------------------------------------
standardBody :: Model -> Node context
standardBody model =
  H.div_
    [ P.class_ "min-h-screen bg-[#F5F5F5] text-[#171717] antialiased dark:bg-neutral-950 dark:text-neutral-100" ]
    [ H.div_
        [ P.class_ "flex min-h-screen w-full flex-col md:h-screen md:max-h-screen md:flex-row md:overflow-hidden" ]
        [ H.main_
            [ P.class_ "flex h-full min-h-0 min-w-0 flex-1 flex-col border-t border-[#E5E5E5] bg-white dark:border-neutral-800 dark:bg-neutral-900 md:border-t-0" ]
            [ H.div_
                [ P.id_ Config.contentScrollId
                , P.class_ "flex h-full min-h-0 w-full flex-1 flex-col items-center justify-start overflow-y-auto bg-white px-8 pb-0 pt-4 dark:bg-neutral-900 md:pt-14"
                -- Scroll does not bubble, so the reading rail's listener is
                -- registered in the capture phase.
                , onWithOptions CAPTURE defaultOptions "scroll" emptyDecoder
                    (\() _ _ -> ScrolledContent)
                ]
                [ H.div_
                    [ P.class_ "w-full max-w-3xl shrink-0 text-left" ]
                    [ siteHeader model
                    , routeContent model
                    ]
                , seaFooter model
                ]
            ]
        ]
    ]
-----------------------------------------------------------------------------
notFoundBody :: MisoString -> Node context
notFoundBody path =
  H.div_
    [ P.class_ "flex min-h-screen w-full flex-col items-center justify-center bg-[#F5F5F5] px-8 text-[#171717] antialiased dark:bg-neutral-950 dark:text-neutral-100" ]
    [ H.h1_ [ P.class_ "text-2xl font-semibold tracking-tight" ] [ text "Not found" ]
    , H.p_ [ P.class_ "mt-2 text-sm text-neutral-500 dark:text-neutral-400" ] [ text path ]
    , internalLink Home
        [ P.class_ "mt-6 text-xs uppercase tracking-[0.2em] text-neutral-500 transition-colors hover:text-[#FF4B26] dark:text-neutral-400 dark:hover:text-[#FF6B4A]" ]
        [ text "Back to the start" ]
    ]
-----------------------------------------------------------------------------
-- | The animated region. @data-route-motion@ is the entire mechanism: the
-- model names a phase, @styles.css@ decides what that phase looks like.
routeContent :: Model -> Node context
routeContent model =
  H.div_
    [ P.id_ Config.pageViewId
    , P.data_ "route-motion" (Model.motionName (_motion model))
    , P.class_ "route-content mt-7"
    ]
    [ pageContent model ]
-----------------------------------------------------------------------------
siteHeader :: Model -> Node context
siteHeader model =
  H.header_
    [ P.class_ "[&_a:focus-visible]:text-[#C24120] [&_a:focus-visible]:outline-2 [&_a:focus-visible]:outline-offset-4 [&_a:focus-visible]:outline-[#C24120] dark:[&_a:focus-visible]:text-[#FF6B4A] dark:[&_a:focus-visible]:outline-[#FF6B4A]" ]
    [ H.div_
        [ P.class_ "w-16" ]
        -- The hollow mark is a WebGL canvas; the widget mounts from these
        -- hooks and reads the lab interaction attribute.
        [ H.canvas_
            [ P.class_ "hollow-mark"
            , P.data_ "lab-interaction" (Model.labInteractionName model)
            , P.role_ "img"
            , textProp "aria-label" "Faah hollow mark"
            , onCreated HollowMounted
            , onBeforeDestroyed HollowDisposed
            ]
            []
        ]
    , H.div_
        [ P.class_ "mt-10 flex flex-wrap items-baseline gap-x-5 gap-y-2" ]
        [ internalLink Home
            [ P.class_ "font-instrument text-[18px] font-semibold tracking-tight text-[#171717] no-underline transition-colors hover:text-[#FF4B26] dark:text-neutral-100 dark:hover:text-[#FF6B4A]" ]
            [ text Config.brandMark ]
        , H.nav_
            [ textProp "aria-label" "Primary navigation"
            , P.class_ "flex items-center gap-4 text-xs leading-none"
            ]
            [ navigationLink active (Section Config.thoughtSection) Config.thoughtSection Config.thoughtSection
            , labLink active
            , themeToggle (_theme model)
            ]
        ]
    ]
  where
    active = Route.activeSection (Model.currentRoute model)
-----------------------------------------------------------------------------
navigationLink :: MisoString -> Route -> MisoString -> MisoString -> Node context
navigationLink active target section label =
  internalLink target
    [ textProp "aria-current" (if current then "page" else "false")
    , P.class_ (linkClass current)
    ]
    [ text label ]
  where
    current = active == section
-----------------------------------------------------------------------------
-- | The lab link is the sea's hover source: enter and focus raise the
-- interaction, leave and blur lower it.
labLink :: MisoString -> Node context
labLink active =
  internalLink (Section Config.labSection)
    [ textProp "aria-current" (if current then "page" else "false")
    , P.data_ "lab-link" "true"
    , E.onMouseEnter HoveredLab
    , E.onMouseLeave LeftLab
    , E.onFocus HoveredLab
    , E.onBlur LeftLab
    , P.class_ (linkClass current)
    ]
    [ text Config.labSection ]
  where
    current = active == Config.labSection
-----------------------------------------------------------------------------
linkClass :: Bool -> MisoString
linkClass = \case
  True  -> "text-[#FF4B26] transition-colors dark:text-[#FF6B4A]"
  False -> "text-neutral-500 transition-colors hover:text-[#FF4B26] dark:text-neutral-400 dark:hover:text-[#FF6B4A]"
-----------------------------------------------------------------------------
themeToggle :: Theme -> Node context
themeToggle current =
  H.button_
    [ P.type_ "button"
    , E.onClick ToggledTheme
    , P.title_ label
    , textProp "aria-label" label
    , P.class_ "footer-theme-toggle"
    ]
    [ H.span_ [ P.class_ "theme-sun" ] [ sunIcon ]
    , H.span_ [ P.class_ "theme-moon" ] [ moonIcon ]
    ]
  where
    label = Theme.toggleLabel current
-----------------------------------------------------------------------------
seaFooter :: Model -> Node context
seaFooter model =
  H.div_
    [ P.class_ "flex w-full min-h-0 flex-1 flex-col self-stretch mt-14" ]
    [ H.div_
        [ P.id_ Config.seaFooterId
        , P.data_ "lab-interaction" (Model.labInteractionName model)
        , P.class_ "relative mt-10 flex min-h-0 w-[calc(100%+4rem)] -mx-8 max-w-none flex-1 overflow-hidden rounded-lg bg-transparent dark:bg-[#171717]"
        ]
        -- The shader canvas. The mount point is the element itself; the
        -- effect lives in Site.Widgets.Sea and runs from these hooks.
        [ H.canvas_
            [ P.id_ Config.seaCanvasId
            , P.class_ "block w-full touch-none bg-transparent"
            , onCreated SeaMounted
            , onBeforeDestroyed SeaDisposed
            ]
            []
        ]
    ]
-----------------------------------------------------------------------------
-- | One page per route, each in its own module.
pageContent :: Model -> Node context
pageContent model =
  case _page model of
    HomePage ->
      homeView
        (GitHub.statusFrom
          (_gitHubProfile model)
          (_gitHubContributions model)
          (_gitHubFailed model))
    SectionPage section ->
      sectionView section
    PostPage section slug ->
      case Content.findPost section slug of
        Nothing   -> notFoundBody (Route.routePath (Post section slug))
        Just post -> postView post (_copyStatus model) (_reading model)
    NotFoundPage path ->
      notFoundBody path
