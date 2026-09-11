-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The whole of the shell's state.
--
-- Two rules keep this module honest as pages arrive:
--
-- * 'Site.Route.Route' is the wire format; 'Page' is the live state. A route
--   is what a URL means, a page is what is currently mounted. They are one to
--   one today because no page has state of its own yet. When a page acquires
--   state -- a fetch in flight, a copy-link confirmation -- it goes in that
--   page's 'Page' constructor, and 'pageForRoute' becomes the place that
--   supplies its initial value. 'Route' stays untouched, so the URL grammar
--   never has to grow a field it does not describe.
--
-- * 'Model' derives 'Eq' because 'Miso.startApp' requires it to skip
--   redundant draws.
module Site.Model
  ( -- * Route transition
    RouteMotion (..)
  , motionName
    -- * Pages
  , Page (..)
  , pageForRoute
  , routeForPage
    -- * Copy link
  , CopyStatus (..)
    -- * Model
  , Model (..)
  , initialModel
  , modelFor
    -- * Lenses
  , page
  , theme
  , motion
  , navigationVersion
  , pendingNavigation
  , labHover
  , gitHubProfile
  , gitHubContributions
  , gitHubFailed
  , copyStatus
  , reading
    -- * Derived
  , currentRoute
  , labInteractionName
  ) where
-----------------------------------------------------------------------------
import           Miso.Lens (Lens, lens)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.GitHub (Contributions, Profile)
import           Site.Route (Route (..))
import           Site.Scroll (ReadingProgress, emptyReadingProgress)
import           Site.Theme (Theme (..))
-----------------------------------------------------------------------------
-- | Where the shell is in a route change.
--
-- The initial value must be 'Idle', not 'Entering'. Prerendered HTML is
-- visible before the WASM module loads, and both other states set
-- @opacity: 0@ in @styles.css@ -- booting into either would blank the page
-- until hydration finished.
data RouteMotion
  = Idle
  | Leaving
  | Entering
  deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Value of the @data-route-motion@ attribute. The CSS selects on these
-- exact strings.
motionName :: RouteMotion -> MisoString
motionName = \case
  Idle     -> "idle"
  Leaving  -> "leaving"
  Entering -> "entering"
-----------------------------------------------------------------------------
-- | The mounted page, with whatever state that page owns.
data Page
  = HomePage
  | SectionPage MisoString
  | PostPage MisoString MisoString
  | NotFoundPage MisoString
  deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Seed a page from the URL it was reached by. This is where per-page
-- initial state will be constructed.
pageForRoute :: Route -> Page
pageForRoute = \case
  Home              -> HomePage
  Section section   -> SectionPage section
  Post section slug -> PostPage section slug
  NotFound path     -> NotFoundPage path
-----------------------------------------------------------------------------
-- | Recover the URL a page is showing. Needed by the view (to mark the active
-- nav item) and by the update (to recognise a navigation that is a no-op).
routeForPage :: Page -> Route
routeForPage = \case
  HomePage              -> Home
  SectionPage section   -> Section section
  PostPage section slug -> Post section slug
  NotFoundPage path     -> NotFound path
-----------------------------------------------------------------------------
-- | The copy-link button's two states. The reset timer returns it to
-- 'NotCopied' after two seconds, as the source did.
data CopyStatus = NotCopied | Copied
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data Model
  = Model
  { _page :: Page
  , _theme :: Theme
  , _motion :: RouteMotion
  , _navigationVersion :: Int
  , _pendingNavigation :: Maybe Route
    -- | Whether the header's lab link is hovered or focused. It drives the
    -- sea's @data-lab-interaction@. Reset on every URL change.
  , _labHover :: Bool
    -- | The GitHub card's two responses, merged by 'Site.GitHub.statusFrom'.
  , _gitHubProfile :: Maybe Profile
  , _gitHubContributions :: Maybe Contributions
  , _gitHubFailed :: Bool
    -- | Post chrome state. Kept at the top level like the source's post
    -- submodel: measurement replaces it on entry, and the copy button
    -- self-resets.
  , _copyStatus :: CopyStatus
  , _reading :: ReadingProgress
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Only correct for the root URL in the light theme. Real boots go through
-- 'modelFor'; this exists as the static @model@ field of the component, which
-- Miso uses when remounting.
initialModel :: Model
initialModel = modelFor Home Light
-----------------------------------------------------------------------------
modelFor :: Route -> Theme -> Model
modelFor target chosen = Model
  { _page   = pageForRoute target
  , _theme  = chosen
  , _motion = Idle
  , _navigationVersion = 0
  , _pendingNavigation = Nothing
  , _labHover = False
  , _gitHubProfile = Nothing
  , _gitHubContributions = Nothing
  , _gitHubFailed = False
  , _copyStatus = NotCopied
  , _reading = emptyReadingProgress
  }
-----------------------------------------------------------------------------
page :: Lens Model Page
page = lens _page (\model value -> model { _page = value })
-----------------------------------------------------------------------------
theme :: Lens Model Theme
theme = lens _theme (\model value -> model { _theme = value })
-----------------------------------------------------------------------------
motion :: Lens Model RouteMotion
motion = lens _motion (\model value -> model { _motion = value })
-----------------------------------------------------------------------------
navigationVersion :: Lens Model Int
navigationVersion = lens _navigationVersion (\model value -> model { _navigationVersion = value })
-----------------------------------------------------------------------------
pendingNavigation :: Lens Model (Maybe Route)
pendingNavigation = lens _pendingNavigation (\model value -> model { _pendingNavigation = value })
-----------------------------------------------------------------------------
labHover :: Lens Model Bool
labHover = lens _labHover (\model value -> model { _labHover = value })
-----------------------------------------------------------------------------
gitHubProfile :: Lens Model (Maybe Profile)
gitHubProfile = lens _gitHubProfile (\model value -> model { _gitHubProfile = value })
-----------------------------------------------------------------------------
gitHubContributions :: Lens Model (Maybe Contributions)
gitHubContributions = lens _gitHubContributions (\model value -> model { _gitHubContributions = value })
-----------------------------------------------------------------------------
gitHubFailed :: Lens Model Bool
gitHubFailed = lens _gitHubFailed (\model value -> model { _gitHubFailed = value })
-----------------------------------------------------------------------------
copyStatus :: Lens Model CopyStatus
copyStatus = lens _copyStatus (\model value -> model { _copyStatus = value })
-----------------------------------------------------------------------------
reading :: Lens Model ReadingProgress
reading = lens _reading (\model value -> model { _reading = value })
-----------------------------------------------------------------------------
currentRoute :: Model -> Route
currentRoute = routeForPage . _page
-----------------------------------------------------------------------------
-- | Value of the sea footer's @data-lab-interaction@: the lab link's hover
-- wins, otherwise being on the lab page counts as engagement.
labInteractionName :: Model -> MisoString
labInteractionName model
  | _labHover model = "hovered"
  | activeSection (currentRoute model) == "lab" = "hovered"
  | otherwise = "idle"
  where
    activeSection = \case
      Section section -> section
      Post section _  -> section
      _               -> ""
