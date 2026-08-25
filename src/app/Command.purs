module App.Command where

import Prelude

import App.Message as AppMessage
import App.Site as Site
import Data.Maybe (Maybe(..))
import Domain.Content as Content
import Domain.Theme as Theme
import Foldkit.Clipboard as Clipboard
import Foldkit.Command as FoldkitCommand
import Foldkit.Media as Media
import Foldkit.Navigation as Navigation
import Foldkit.Render as Render
import Foldkit.Root as Root
import Foldkit.Storage as Storage
import Page.Home.Command as Home
import Page.Home.Message as HomeMessage
import Page.Post.Command as Post
import Page.Post.Message as PostMessage
import Platform.Browser as Browser
import PursTs.Effect as Fx

data Command
  = NavigateInternal String
  | LoadExternal String
  | StartRouteEntry
  | LoadGitHub String
  | CopyPostLink String
  | ResetCopyStatus
  | ReadTheme
  | PersistTheme Theme.Theme
  | ResetScroll
  | SyncDocumentMetadata Content.DocumentMetadata

fromHome :: Home.Command -> Command
fromHome command = case command of
  Home.LoadGitHub -> LoadGitHub Site.githubUsername

fromPost :: Post.Command -> Command
fromPost command = case command of
  Post.CopyLink url -> CopyPostLink url
  Post.ResetCopyStatus -> ResetCopyStatus

applyTheme
  :: Theme.Theme -> Fx.Effect Fx.Never Fx.NoServices Unit
applyTheme theme = case theme of
  Theme.Dark -> do
    Root.toggleClass "dark" true
    Root.setColorScheme "dark"
  Theme.Light -> do
    Root.toggleClass "dark" false
    Root.setColorScheme "light"

toRuntime :: Command -> FoldkitCommand.Command AppMessage.Message
toRuntime command = case command of
  NavigateInternal url -> FoldkitCommand.named "NavigateInternal" { url } \_ -> do
    Render.afterPaint
    reduceMotion <- Media.prefersReducedMotion
    if reduceMotion then pure unit else Fx.sleepMilliseconds 250
    Fx.as AppMessage.CompletedNavigateInternal (Navigation.pushUrl url)
  LoadExternal href -> FoldkitCommand.named "LoadExternal" { href } \_ ->
    Fx.as AppMessage.CompletedLoadExternal (Navigation.load href)
  StartRouteEntry -> FoldkitCommand.namedNoArgs "StartRouteEntry" \_ ->
    Fx.as AppMessage.StartedRouteEntry Render.afterPaint
  LoadGitHub username -> FoldkitCommand.named "LoadGitHub" { username } \_ ->
    Fx.match (Browser.loadGitHub username)
      { onFailure: const (AppMessage.GotHomeMessage HomeMessage.FailedLoadGitHub)
      , onSuccess: AppMessage.GotHomeMessage <<< HomeMessage.SucceededLoadGitHub
      }
  CopyPostLink url -> FoldkitCommand.named "CopyPostLink" { url } \_ ->
    Fx.match (Clipboard.writeText url)
      { onFailure: const (AppMessage.GotPostMessage PostMessage.FailedCopyLink)
      , onSuccess: const (AppMessage.GotPostMessage PostMessage.SucceededCopyLink)
      }
  ResetCopyStatus -> FoldkitCommand.namedNoArgs "ResetCopyStatus" \_ -> do
    Fx.sleepMilliseconds 2000
    Fx.succeed (AppMessage.GotPostMessage PostMessage.CompletedResetCopyStatus)
  ReadTheme -> FoldkitCommand.namedNoArgs "ReadTheme" \_ ->
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
  PersistTheme theme -> FoldkitCommand.named "PersistTheme" { theme: Theme.toString theme } \_ ->
    do
      saved <- Fx.match (Storage.set "theme" (case theme of
        Theme.Dark -> "dark"
        Theme.Light -> "light"))
        { onFailure: const false
        , onSuccess: const true
        }
      applyTheme theme
      pure (if saved then AppMessage.CompletedPersistTheme else AppMessage.FailedPersistTheme)
  ResetScroll -> FoldkitCommand.namedNoArgs "ResetScroll" \_ ->
    Fx.match Browser.resetScroll
      { onFailure: const AppMessage.FailedResetScroll
      , onSuccess: const AppMessage.CompletedResetScroll
      }
  SyncDocumentMetadata metadata -> FoldkitCommand.named "SyncDocumentMetadata" metadata \_ ->
    Fx.match (Browser.syncDocumentMetadata metadata)
      { onFailure: const AppMessage.FailedSyncDocumentMetadata
      , onSuccess: const AppMessage.CompletedSyncDocumentMetadata
      }
