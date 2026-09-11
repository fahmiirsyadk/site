-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | Wiring. The three functions the runtime needs, plus the one subscription.
module Site.App
  ( app
  , bootModel
  , siteEvents
  ) where
-----------------------------------------------------------------------------
import qualified Data.Map as M
import           Miso
                 ( App
                 , Component (..)
                 , Events
                 , component
                 , defaultEvents
                 , getURI
                 , keyboardEvents
                 , mouseEvents
                 , uriSub
                 )
import           Miso.Event (Phase (CAPTURE))
-----------------------------------------------------------------------------
import           Site.Action (Action (..))
import           Site.Model (Model, modelFor)
import qualified Site.Platform as Platform
import qualified Site.Route as Route
import           Site.Theme (Theme (..))
import           Site.Update (updateModel)
import           Site.View (viewModel)
-----------------------------------------------------------------------------
-- | Delegated events the shell listens for.
--
-- 'defaultEvents' covers the click on a navigation link and the theme button.
-- 'mouseEvents' brings the lab link's @mouseenter@\/@mouseleave@ and
-- 'keyboardEvents' the reading rail's key handling.
--
-- @scroll@ is added by hand, in the capture phase: scroll events do not
-- bubble, so a body-level bubble listener would never see the inner content
-- container scroll. Capture reaches it.
siteEvents :: Events
siteEvents =
  defaultEvents
    <> mouseEvents
    <> keyboardEvents
    <> M.fromList [("scroll", CAPTURE)]
-----------------------------------------------------------------------------
-- | Read the starting state out of the browser. 'Main.main' calls this for
-- the static @model@ field, which is what a remount draws from.
--
-- Everything in here is synchronous, as is 'staticBootModel'.
bootModel :: IO Model
bootModel = do
  uri <- getURI
  chosen <- Platform.bootTheme
  Platform.applyTheme chosen
  pure (modelFor (Route.uriToRoute uri) chosen)
-----------------------------------------------------------------------------
-- | The model hydration starts from: the same deterministic value the
-- prerender generator wrote into the page, with 'Light' as the theme.
--
-- Theme is the one thing the server cannot know -- it depends on storage and
-- the system preference. Rather than let the two disagree, the generated
-- markup is theme-independent and the component's @mount@ action
-- ('AdoptedTheme') applies the real theme right after hydration, drawing once
-- when the reader came back in dark mode. This is why @hydrateModel@ is not
-- 'bootModel': the DOM was built with 'Light'.
staticBootModel :: IO Model
staticBootModel = do
  uri <- getURI
  pure (modelFor (Route.uriToRoute uri) Light)
-----------------------------------------------------------------------------
-- | The application, seeded with a model the caller has already booted.
--
-- Taking the model as an argument rather than reading the URL inside keeps
-- the value pure, which is what the prerender generator needs: it supplies a
-- model per route and never touches 'bootModel'.
app :: Model -> App Model Action
app initial = (component initial updateModel viewModel)
  { subs = [ uriSub ChangedURI ]
  , hydrateModel = Just staticBootModel
  , mount = Just SyncTheme
  }
