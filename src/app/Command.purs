module App.Command where

import Prelude

import App.Message as AppMessage
import App.Site as Site
import Data.Maybe (Maybe(..))
import Domain.Content as Content
import Domain.Theme as Theme
import Foldkit.Command as FoldkitCommand
import Foldkit.Media as Media
import Foldkit.Navigation as Navigation
import Foldkit.Render as Render
import Foldkit.Root as Root
import Foldkit.Storage as Storage
import Platform.Browser as Browser
import Platform.Browser.Scroll as Scroll
import Platform.Effect as PE
import PursTs.Effect as Fx

applyTheme
  :: Theme.Theme -> Fx.Effect Fx.Never Fx.NoServices Unit
applyTheme theme = case theme of
  Theme.Dark -> do
    Root.toggleClass "dark" true
    Root.setColorScheme "dark"
  Theme.Light -> do
    Root.toggleClass "dark" false
    Root.setColorScheme "light"

navigateInternal :: String -> FoldkitCommand.Command AppMessage.Message
navigateInternal url = FoldkitCommand.named "NavigateInternal" { url } \_ -> do
  Render.afterPaint
  reduceMotion <- Media.prefersReducedMotion
  if reduceMotion then pure unit else PE.delay (PE.Milliseconds 250)
  Fx.as AppMessage.CompletedNavigateInternal (Navigation.pushUrl url)

navigateHeading :: String -> String -> FoldkitCommand.Command AppMessage.Message
navigateHeading path heading =
  FoldkitCommand.named "NavigateHeading" { path, heading } \_ ->
    Fx.as AppMessage.CompletedNavigateHeading (Navigation.pushUrl (path <> "#" <> heading))

scrollToHeading :: String -> FoldkitCommand.Command AppMessage.Message
scrollToHeading heading = FoldkitCommand.named "ScrollToHeading" { heading } \_ -> do
  Render.afterPaint
  reduceMotion <- Media.prefersReducedMotion
  Scroll.scrollToHeading Site.contentScrollSelector heading (not reduceMotion)
  pure AppMessage.CompletedScrollToHeading

scrollToProgress :: Int -> FoldkitCommand.Command AppMessage.Message
scrollToProgress progress = FoldkitCommand.named "ScrollToProgress" { progress } \_ -> do
  Render.afterPaint
  reduceMotion <- Media.prefersReducedMotion
  Scroll.scrollToProgress Site.contentScrollSelector progress (not reduceMotion)
  pure AppMessage.CompletedScrollToProgress

loadExternal :: String -> FoldkitCommand.Command AppMessage.Message
loadExternal href = FoldkitCommand.named "LoadExternal" { href } \_ ->
  Fx.as AppMessage.CompletedLoadExternal (Navigation.load href)

startRouteEntry :: FoldkitCommand.Command AppMessage.Message
startRouteEntry = FoldkitCommand.namedNoArgs "StartRouteEntry" \_ ->
  Fx.as AppMessage.StartedRouteEntry Render.afterPaint

readTheme :: FoldkitCommand.Command AppMessage.Message
readTheme = FoldkitCommand.namedNoArgs "ReadTheme" \_ ->
  do
    stored <- Fx.match (Storage.get "theme")
      { onFailure: const Nothing
      , onSuccess: identity
      }
    dark <- case stored of
      Just value -> pure (value == "dark")
      Nothing -> Media.prefersDarkColorScheme
    let theme = if dark then Theme.Dark else Theme.Light
    applyTheme theme
    pure (AppMessage.LoadedTheme theme)

persistTheme :: Theme.Theme -> FoldkitCommand.Command AppMessage.Message
persistTheme theme = FoldkitCommand.named "PersistTheme" { theme: Theme.toString theme } \_ ->
  do
    saved <- Fx.match (Storage.set "theme" (case theme of
      Theme.Dark -> "dark"
      Theme.Light -> "light"))
      { onFailure: const false
      , onSuccess: const true
      }
    applyTheme theme
    pure (if saved then AppMessage.CompletedPersistTheme else AppMessage.FailedPersistTheme)

resetScroll :: FoldkitCommand.Command AppMessage.Message
resetScroll = FoldkitCommand.namedNoArgs "ResetScroll" \_ ->
  Fx.match Browser.resetScroll
    { onFailure: const AppMessage.FailedResetScroll
    , onSuccess: const AppMessage.CompletedResetScroll
    }

syncDocumentMetadata :: Content.DocumentMetadata -> FoldkitCommand.Command AppMessage.Message
syncDocumentMetadata metadata = FoldkitCommand.named "SyncDocumentMetadata" metadata \_ ->
  Fx.match (Browser.syncDocumentMetadata metadata)
    { onFailure: const AppMessage.FailedSyncDocumentMetadata
    , onSuccess: const AppMessage.CompletedSyncDocumentMetadata
    }
