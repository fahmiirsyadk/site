-----------------------------------------------------------------------------
-- | Everything that can happen to the shell.
--
-- Named for what occurred, not for what should follow: a click on an internal
-- link is 'FollowedLink', and the decision to animate out, push history and
-- swap pages belongs to 'Site.Update'. No constructor here is unhandled.
module Site.Action
  ( Action (..)
  , Element (..)
  ) where
-----------------------------------------------------------------------------
import           Miso (URI)
import           Miso.DSL (JSVal)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.GitHub (Contributions, Profile)
import           Site.Model (PostRequest)
import           Site.Route (Route)
import           Site.Scroll (ReadingProgress)
import           Site.Theme (Theme)

-- | Opaque DOM identity retained by lifecycle actions.
newtype Element = Element JSVal deriving (Eq)

instance Show Element where
  show _ = "<element>"
-----------------------------------------------------------------------------
data Action
  = FollowedLink Route
  -- ^ An ordinary primary internal-link activation was intercepted before the
  -- browser default ran. The URL has not changed yet.
  | IgnoredLinkClick
  -- ^ A modified or non-primary internal-link click remains browser-owned.
  | ChangedURI URI
  -- ^ The URL did change, whether by 'Miso.pushURI' from 'FollowedLink' or by
  -- the back and forward buttons. Delivered by @uriSub@; this is the only
  -- action that swaps the page.
  | NavigationReady Int Route
  -- ^ The delayed leave completed. The version and target guard stale timers.
  | EnteredRoute Int
  -- ^ The entry delay completed. The version guards stale entry timers before
  -- allowing the current page to transition in.
  | ToggledTheme
  | AppMounted
  | AppDisposed
  -- ^ The shell mounted; read the stored or system theme.
  | AdoptedTheme Theme
  -- ^ The theme read at mount, ready to make the model agree with the class
  -- the anti-flash script already applied.
  | SeaMounted Element
  -- ^ The sea canvas entered the document. Fires during hydration and on
  -- every client-side mount; the effect itself is idempotent.
  | SeaDisposed Element
  -- ^ The sea canvas left the document; release its WebGL context.
  | HoveredLab
  | LeftLab
  -- ^ The header's lab link, which drives the sea's hover uniform.
  | LoadedGitHubProfile Profile
  -- ^ One of the home card's two responses. The card flips to ready only
  -- when both have arrived.
  | LoadedGitHubContributions Contributions
  | FailedGitHub
  | ScrolledContent
  -- ^ The post's scroll container moved. Captured, because scroll events do
  -- not bubble.
   | MeasuredReadingProgress Int ReadingProgress
  -- ^ A fresh measurement of the reading rail's geometry.
  | SelectedReadingProgress Int
  -- ^ The reader picked an exact position on the rail, by click or by
  -- @Home@/@End@.
  | AdjustedReadingProgress Int
  -- ^ The reader stepped the rail by a delta, with the arrow or page keys.
  | ReadingSliderMounted Element
  | ReadingSliderDisposed Element
  | ClickedCopyLink MisoString
   | CopiedLink PostRequest
   | FailedCopyLink PostRequest
   | CopyStatusExpired PostRequest
  -- ^ The copy confirmation's reset timer elapsed.
  | IgnoredKey
  -- ^ A key on the reading slider that has no binding.
  | ScribbleMounted Element
  | ScribbleDisposed Element
  -- ^ The home page's scribble span; the widget loops its animation.
  | HollowMounted Element
  | HollowDisposed Element
  -- ^ The header's hollow mark canvas; drag-to-spin WebGL.
  deriving (Show, Eq)
-----------------------------------------------------------------------------
