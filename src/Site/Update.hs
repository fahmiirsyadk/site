-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase #-}
-----------------------------------------------------------------------------
-- | The transition function.
--
-- The route change is the one piece of real choreography in the shell, and it
-- is spread across four actions:
--
-- @
--   FollowedLink     -- mark Leaving and start the exit delay
--   NavigationReady  -- validate the intent and push history synchronously
--   ChangedURI       -- swap the page, mark Entering, reset scroll
--   EnteredRoute     -- validate the entry and mark Idle
-- @
--
-- Only 'Site.Action.ChangedURI' swaps the page, so the back and forward
-- buttons, which arrive through @uriSub@ without a 'Site.Action.FollowedLink'
-- before them, take the same path as a click. The cost is that browser
-- navigation skips the exit animation; the benefit is one code path.
module Site.Update
  ( updateModel
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (unless, when)
import           Miso (Effect, io, io_, pushURI, sync_)
import           Miso.Fetch (Response (..), getJSON)
import           Miso.Lens (use, (.=))
import           Miso.Navigator (copyClipboard)
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.Action (Action (..))
import qualified Site.Config as Config
import qualified Site.GitHub as GitHub
import           Site.Model
                 ( CopyStatus (..)
                 , Model
                 , RouteMotion (..)
                 , copyStatus
                 , gitHubContributions
                 , gitHubFailed
                 , gitHubProfile
                 , labHover
                 , motion
                 , navigationVersion
                 , page
                 , pendingNavigation
                 , reading
                 , theme
                 )
import qualified Site.Model as Model
import qualified Site.Platform as Platform
import qualified Site.Route as Route
import qualified Site.Scroll as Scroll
import           Site.Scroll (ReadingProgress (..), emptyReadingProgress)
import qualified Site.Theme as Theme
import qualified Site.Widgets.Dither as Dither
import qualified Site.Widgets.Hollow as Hollow
import qualified Site.Widgets.Scribble as Scribble
import qualified Site.Widgets.Scroll as ScrollWidget
import qualified Site.Widgets.Sea as Sea
-----------------------------------------------------------------------------
updateModel :: Action -> Effect context props Model Action
updateModel = \case

  FollowedLink target -> do
    current <- Model.routeForPage <$> use page
    currentMotion <- use motion
    pending <- use pendingNavigation
    unless (target == current && pending == Nothing && currentMotion == Idle) $ do
      version <- (+ 1) <$> use navigationVersion
      navigationVersion .= version
      pendingNavigation .= Nothing
      if target == current
        then motion .= Idle
        else do
          pendingNavigation .= Just target
          motion .= Leaving
          io $ do
            reduced <- Platform.prefersReducedMotion
            unless reduced (Platform.delayMs Config.routeLeaveMs)
            pure (NavigationReady version target)

  IgnoredLinkClick ->
    pure ()

  NavigationReady version target -> do
    current <- Model.routeForPage <$> use page
    pending <- use pendingNavigation
    currentVersion <- use navigationVersion
    when (pending == Just target && version == currentVersion && target /= current) $ do
      pendingNavigation .= Nothing
      sync_ (pushURI (Route.routeURI target))

  ChangedURI uri -> do
    let target = Route.uriToRoute uri
    current <- Model.routeForPage <$> use page
    currentMotion <- use motion
    pending <- use pendingNavigation
    unless (target == current && pending == Nothing && currentMotion == Idle) $ do
      version <- (+ 1) <$> use navigationVersion
      navigationVersion .= version
      pendingNavigation .= Nothing
      if target == current
        then motion .= Idle
        else do
          page .= Model.pageForRoute target
          motion .= Entering
          labHover .= False
          reading .= emptyReadingProgress
          copyStatus .= NotCopied
          io $ do
            Platform.resetContentScroll
            Platform.delayMs Config.routeEntryMs
            pure (EnteredRoute version)

  EnteredRoute version -> do
    currentVersion <- use navigationVersion
    pending <- use pendingNavigation
    when (version == currentVersion && pending == Nothing) $ do
      motion .= Idle
      measureIfPost

  ToggledTheme -> do
    next <- Theme.toggle <$> use theme
    theme .= next
    io_ $ do
      Platform.applyTheme next
      Platform.storeTheme next

  -- After hydration the DOM already shows the right theme (the anti-flash
  -- script applied it), but the model was built for the prerendered markup.
  -- Reading and adopting the real value here draws exactly once when they
  -- differ -- a dark-mode reader gets the dark toggle label -- and not at
  -- all otherwise.
  AppMounted -> do
    io $ do
      chosen <- Platform.bootTheme
      Platform.applyTheme chosen
      pure (AdoptedTheme chosen)
    -- The canvas @onCreated@ hook also mounts the shader; this second entry
    -- point runs once the component is mounted for certain and covers a
    -- hydration walk that did not dispatch the element hook. Idempotent.
    io_ Sea.attach
    -- Dithered images have no element hook: the widget watches the body for
    -- roots appearing and leaving as Miso patches page content, so one
    -- attach per app lifetime is enough.
    io_ Dither.attach
    -- The home card's data loads once per app lifetime, like the source's
    -- init command. A failed start is not retried.
    profile <- use gitHubProfile
    contributions <- use gitHubContributions
    failed <- use gitHubFailed
    when (profile == Nothing && contributions == Nothing && not failed) $ do
      getJSON GitHub.profileUrl [] (LoadedGitHubProfile . body) gitHubError
      getJSON GitHub.contributionsUrl [] (LoadedGitHubContributions . body) gitHubError

  AdoptedTheme chosen ->
    theme .= chosen

  -- The canvas hooks. Mounting during hydration is deliberate: the
  -- prerendered page boots the shader as soon as the WASM module adopts it.
  SeaMounted ->
    io_ Sea.attach

  SeaDisposed ->
    io_ Sea.dispose

  HoveredLab ->
    labHover .= True

  LeftLab ->
    labHover .= False

  LoadedGitHubProfile profile ->
    gitHubProfile .= Just profile

  LoadedGitHubContributions contributions ->
    gitHubContributions .= Just contributions

  FailedGitHub ->
    gitHubFailed .= True

  ScrolledContent ->
    measureIfPost

  MeasuredReadingProgress progress -> do
    current <- use reading
    when (progress /= current) (reading .= progress)

  SelectedReadingProgress percent ->
    io_ (ScrollWidget.scrollToProgress (Scroll.clampProgress percent))

  AdjustedReadingProgress delta -> do
    current <- use reading
    io_ (ScrollWidget.scrollToProgress (Scroll.clampProgress (readingPercent current + delta)))

  ClickedCopyLink url ->
    copyClipboard url CopiedLink (const FailedCopyLink)

  CopiedLink -> do
    copyStatus .= Copied
    io $ do
      Platform.delayMs 2000
      pure CopyStatusExpired

  FailedCopyLink ->
    pure ()

  CopyStatusExpired ->
    copyStatus .= NotCopied

  IgnoredKey ->
    pure ()

  ScribbleMounted ->
    io_ Scribble.attach

  ScribbleDisposed ->
    io_ Scribble.dispose

  HollowMounted ->
    io_ Hollow.attach

  HollowDisposed ->
    io_ Hollow.dispose
-----------------------------------------------------------------------------
-- | A reading measurement only makes sense while a post is the mounted page,
-- and only after the post's DOM has been drawn: 'EnteredRoute' fires after
-- the entry delay, and every captured scroll event fires after a paint.
measureIfPost :: Effect context props Model Action
measureIfPost = do
  target <- Model.routeForPage <$> use page
  case target of
    Route.Post _ _ ->
      io (MeasuredReadingProgress <$> ScrollWidget.measureReadingProgress)
    _ ->
      pure ()

-- | The error callback's payload is unused; naming its type pins
-- @FromJSVal@ to 'MisoString'.
gitHubError :: Response MisoString -> Action
gitHubError _ = FailedGitHub
-----------------------------------------------------------------------------
