-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
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
import           Site.Action (Action (..), Element (..))
import qualified Site.Config as Config
import qualified Site.GitHub as GitHub
import           Site.Model
                 ( CopyStatus (..)
                 , Model
                  , Navigation (..)
                  , Page (..)
                  , PostState (..)
                  , PostRequest (..)
                 , gitHubContributions
                 , gitHubFailed
                 , gitHubProfile
                 , labHover
                  , navigation
                 , navigationVersion
                 , page
                 , theme
                 )
import qualified Site.Model as Model
import qualified Site.Platform as Platform
import qualified Site.Route as Route
import qualified Site.Section as Section
import qualified Site.Scroll as Scroll
import           Site.Scroll (ReadingProgress (..))
import qualified Site.Theme as Theme
import qualified Site.Widgets.Dither as Dither
import qualified Site.Widgets.Browser as Browser
import qualified Site.Widgets.Runtime as Widgets
import qualified Site.Widgets.Scroll as ScrollWidget
-----------------------------------------------------------------------------
updateModel :: Widgets.Runtime -> Action -> Effect context props Model Action
updateModel widgets = \case

  FollowedLink target -> do
    current <- Model.routeForPage <$> use page
    currentNavigation <- use navigation
    unless (target == current && currentNavigation == Settled) $ do
      version <- (+ 1) <$> use navigationVersion
      navigationVersion .= version
      if target == current
        then navigation .= Settled
        else do
          navigation .= LeavingFor target
          io $ do
            reduced <- Platform.prefersReducedMotion
            unless reduced (Platform.delayMs Config.routeLeaveMs)
            pure (NavigationReady version target)

  IgnoredLinkClick ->
    pure ()

  NavigationReady version target -> do
    current <- Model.routeForPage <$> use page
    currentNavigation <- use navigation
    currentVersion <- use navigationVersion
    when (currentNavigation == LeavingFor target && version == currentVersion && target /= current) $ do
      navigation .= AwaitingURI target
      sync_ (pushURI (Route.routeURI target))

  ChangedURI uri -> do
    let target = Route.uriToRoute uri
    current <- Model.routeForPage <$> use page
    currentNavigation <- use navigation
    unless (target == current && currentNavigation == Settled) $ do
      version <- (+ 1) <$> use navigationVersion
      navigationVersion .= version
      if target == current
        then navigation .= Settled
        else do
          page .= Model.pageForRoute version target
          navigation .= EnteringPage
          labHover .= False
          io $ do
            Platform.resetContentScroll
            Platform.delayMs Config.routeEntryMs
            pure (EnteredRoute version)

  EnteredRoute version -> do
    currentVersion <- use navigationVersion
    currentNavigation <- use navigation
    when (version == currentVersion && currentNavigation == EnteringPage) $ do
      navigation .= Settled
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
    io_ $ do
      Browser.mountSelector (Widgets.sea widgets) ("#" <> Config.seaCanvasId)
      Browser.mountSelector (Widgets.hollow widgets) Config.hollowMarkSelector
      Browser.mountSelector (Widgets.scribble widgets) Config.scribbleSelector
    -- Dithered images have no element hook: the widget watches the body for
    -- roots appearing and leaving as Miso patches page content, so one
    -- attach per app lifetime is enough.
    io_ (Dither.attach (Widgets.dither widgets))
    measureIfPost
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

  AppDisposed ->
    io_ (Widgets.disposeRuntime widgets)

  -- The canvas hooks. Mounting during hydration is deliberate: the
  -- prerendered page boots the shader as soon as the WASM module adopts it.
  SeaMounted (Element element) ->
    io_ (Browser.mountElement (Widgets.sea widgets) element)

  SeaDisposed (Element element) ->
    io_ (Browser.disposeElement (Widgets.sea widgets) element)

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

  MeasuredReadingProgress generation progress ->
    withPost $ \section slug state ->
      when (generation == postGeneration state && progress /= postReading state) $
        page .= PostPage section slug state { postReading = progress }

  SelectedReadingProgress percent ->
    withPost $ \_ _ _ ->
      io_ (ScrollWidget.scrollToProgress (Scroll.clampProgress percent))

  AdjustedReadingProgress delta ->
    withPost $ \_ _ state ->
      io_ (ScrollWidget.scrollToProgress (Scroll.clampProgress (readingPercent (postReading state) + delta)))

  ClickedCopyLink url ->
    withPost $ \section slug state -> do
      let version = postCopyVersion state + 1
          request = PostRequest (postGeneration state) version
      page .= PostPage section slug state { postCopyVersion = version }
      copyClipboard url (CopiedLink request) (const (FailedCopyLink request))

  CopiedLink request ->
    withCopyRequest request $ \section slug state -> do
      page .= PostPage section slug state { postCopyStatus = Copied }
      io $ do
        Platform.delayMs 2000
        pure (CopyStatusExpired request)

  FailedCopyLink _ ->
    pure ()

  CopyStatusExpired request ->
    withCopyRequest request $ \section slug state ->
      page .= PostPage section slug state { postCopyStatus = NotCopied }

  IgnoredKey ->
    pure ()

  ReadingSliderMounted (Element element) ->
    io_ (Browser.mountElement (Widgets.readingSlider widgets) element)

  ReadingSliderDisposed (Element element) ->
    io_ (Browser.disposeElement (Widgets.readingSlider widgets) element)

  ScribbleMounted (Element element) ->
    io_ (Browser.mountElement (Widgets.scribble widgets) element)

  ScribbleDisposed (Element element) ->
    io_ (Browser.disposeElement (Widgets.scribble widgets) element)

  HollowMounted (Element element) ->
    io_ (Browser.mountElement (Widgets.hollow widgets) element)

  HollowDisposed (Element element) ->
    io_ (Browser.disposeElement (Widgets.hollow widgets) element)
-----------------------------------------------------------------------------
-- | A reading measurement only makes sense while a post is the mounted page,
-- and only after the post's DOM has been drawn: 'EnteredRoute' fires after
-- the entry delay, and every captured scroll event fires after a paint.
measureIfPost :: Effect context props Model Action
measureIfPost = do
   withPost $ \_ _ state ->
     io (MeasuredReadingProgress (postGeneration state) <$> ScrollWidget.measureReadingProgress)

withPost
  :: (Section.Section -> MisoString -> PostState -> Effect context props Model Action)
  -> Effect context props Model Action
withPost action = do
  current <- use page
  case current of
    PostPage section slug state -> action section slug state
    _ -> pure ()

withCopyRequest
  :: PostRequest
  -> (Section.Section -> MisoString -> PostState -> Effect context props Model Action)
  -> Effect context props Model Action
withCopyRequest request action =
  withPost $ \section slug state ->
    when (request == PostRequest (postGeneration state) (postCopyVersion state)) $
      action section slug state

-- | The error callback's payload is unused; naming its type pins
-- @FromJSVal@ to 'MisoString'.
gitHubError :: Response MisoString -> Action
gitHubError _ = FailedGitHub
-----------------------------------------------------------------------------
