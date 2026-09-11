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
   , Navigation (..)
   , navigationMotion
   , pendingRoute
    -- * Pages
  , Page (..)
  , pageForRoute
  , routeForPage
    -- * Copy link
   , CopyStatus (..)
   , PostState (..)
   , PostRequest (..)
    -- * Model
  , Model (..)
  , initialModel
  , modelFor
    -- * Lenses
  , page
  , theme
   , navigation
  , navigationVersion
  , labHover
  , gitHubProfile
  , gitHubContributions
  , gitHubFailed
    -- * Derived
  , currentRoute
  , labInteractionName
  ) where
-----------------------------------------------------------------------------
import           Miso.Lens (Lens, lens)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.GitHub (Contributions, Profile)
import           Site.Route (Route (..))
import qualified Site.Route as Route
import           Site.Scroll (ReadingProgress, emptyReadingProgress)
import           Site.Theme (Theme (..))
import qualified Site.Section as Section
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

-- | History commitment is distinct from a pending leave: a duplicate timer
-- must not push the same URI again while we await the subscription event.
data Navigation = Settled | LeavingFor Route | AwaitingURI Route | EnteringPage
  deriving (Show, Eq)

navigationMotion :: Navigation -> RouteMotion
navigationMotion = \case
  Settled -> Idle
  LeavingFor _ -> Leaving
  AwaitingURI _ -> Leaving
  EnteringPage -> Entering

pendingRoute :: Navigation -> Maybe Route
pendingRoute (LeavingFor target) = Just target
pendingRoute _ = Nothing
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
   | SectionPage Section.Section
   | PostPage Section.Section MisoString PostState
  | NotFoundPage MisoString
  deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Seed a page from the URL it was reached by. This is where per-page
-- initial state will be constructed.
pageForRoute :: Int -> Route -> Page
pageForRoute generation = \case
  Home              -> HomePage
  Section section   -> SectionPage section
  Post section slug -> PostPage section slug
    (PostState generation 0 NotCopied emptyReadingProgress)
  NotFound path     -> NotFoundPage path
-----------------------------------------------------------------------------
-- | Recover the URL a page is showing. Needed by the view (to mark the active
-- nav item) and by the update (to recognise a navigation that is a no-op).
routeForPage :: Page -> Route
routeForPage = \case
  HomePage              -> Home
  SectionPage section   -> Section section
  PostPage section slug _ -> Post section slug
  NotFoundPage path     -> NotFound path
-----------------------------------------------------------------------------
-- | The copy-link button's two states. The reset timer returns it to
-- 'NotCopied' after two seconds, as the source did.
data CopyStatus = NotCopied | Copied
  deriving (Show, Eq)

data PostState = PostState
  { postGeneration :: Int
  , postCopyVersion :: Int
  , postCopyStatus :: CopyStatus
  , postReading :: ReadingProgress
  } deriving (Show, Eq)

-- | Identity of replaceable work within one mounted post.
data PostRequest = PostRequest Int Int
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data Model
  = Model
  { _page :: Page
  , _theme :: Theme
   , _navigation :: Navigation
   , _navigationVersion :: Int
    -- | Whether the header's lab link is hovered or focused. It drives the
    -- sea's @data-lab-interaction@. Reset on every URL change.
  , _labHover :: Bool
    -- | The GitHub card's two responses, merged by 'Site.GitHub.statusFrom'.
  , _gitHubProfile :: Maybe Profile
  , _gitHubContributions :: Maybe Contributions
  , _gitHubFailed :: Bool
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
   { _page   = pageForRoute 0 target
  , _theme  = chosen
   , _navigation = Settled
  , _navigationVersion = 0
  , _labHover = False
  , _gitHubProfile = Nothing
  , _gitHubContributions = Nothing
  , _gitHubFailed = False
  }
-----------------------------------------------------------------------------
page :: Lens Model Page
page = lens _page (\model value -> model { _page = value })
-----------------------------------------------------------------------------
theme :: Lens Model Theme
theme = lens _theme (\model value -> model { _theme = value })
-----------------------------------------------------------------------------
navigation :: Lens Model Navigation
navigation = lens _navigation (\model value -> model { _navigation = value })
-----------------------------------------------------------------------------
navigationVersion :: Lens Model Int
navigationVersion = lens _navigationVersion (\model value -> model { _navigationVersion = value })
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
currentRoute :: Model -> Route
currentRoute = routeForPage . _page
-----------------------------------------------------------------------------
-- | Value of the sea footer's @data-lab-interaction@: the lab link's hover
-- wins, otherwise being on the lab page counts as engagement.
labInteractionName :: Model -> MisoString
labInteractionName model
  | _labHover model = Config.labInteractionHovered
  | Route.activeSection (currentRoute model) == Just Config.labSection =
      Config.labInteractionHovered
  | otherwise = Config.labInteractionIdle
