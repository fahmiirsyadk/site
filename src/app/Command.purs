module App.Command where

import Prelude

import App.Message as AppMessage
import App.Site as Site
import Domain.Content as Content
import Domain.Theme as Theme
import Foldkit.Command as FoldkitCommand
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

toRuntime :: Command -> FoldkitCommand.Command AppMessage.Message
toRuntime command = case command of
  NavigateInternal url -> FoldkitCommand.named "NavigateInternal" { url } \_ -> do
    Browser.afterPaint
    reduceMotion <- Browser.prefersReducedMotion
    if reduceMotion then pure unit else Fx.sleepMilliseconds 250
    Fx.catchAll
      (Fx.as AppMessage.CompletedNavigateInternal (Browser.pushUrl url))
      (const (Fx.succeed AppMessage.FailedNavigateInternal))
  LoadExternal href -> FoldkitCommand.named "LoadExternal" { href } \_ ->
    Fx.catchAll
      (Fx.as AppMessage.CompletedLoadExternal (Browser.loadExternal href))
      (const (Fx.succeed AppMessage.FailedLoadExternal))
  StartRouteEntry -> FoldkitCommand.namedNoArgs "StartRouteEntry" \_ ->
    Fx.as AppMessage.StartedRouteEntry Browser.afterPaint
  LoadGitHub username -> FoldkitCommand.named "LoadGitHub" { username } \_ ->
    Fx.match (Browser.loadGitHub username)
      { onFailure: const (AppMessage.GotHomeMessage HomeMessage.FailedLoadGitHub)
      , onSuccess: AppMessage.GotHomeMessage <<< HomeMessage.SucceededLoadGitHub
      }
  CopyPostLink url -> FoldkitCommand.named "CopyPostLink" { url } \_ ->
    Fx.match (Browser.copyPostLink url)
      { onFailure: const (AppMessage.GotPostMessage PostMessage.FailedCopyLink)
      , onSuccess: const (AppMessage.GotPostMessage PostMessage.SucceededCopyLink)
      }
  ResetCopyStatus -> FoldkitCommand.namedNoArgs "ResetCopyStatus" \_ -> do
    Fx.sleepMilliseconds 2000
    Fx.succeed (AppMessage.GotPostMessage PostMessage.CompletedResetCopyStatus)
  ReadTheme -> FoldkitCommand.namedNoArgs "ReadTheme" \_ ->
    Fx.match Browser.readTheme
      { onFailure: const AppMessage.FailedReadTheme
      , onSuccess: AppMessage.LoadedTheme <<< Theme.fromString
      }
  PersistTheme theme -> FoldkitCommand.named "PersistTheme" { theme: Theme.toString theme } \_ ->
    Fx.match (Browser.persistTheme (Theme.toString theme))
      { onFailure: const AppMessage.FailedPersistTheme
      , onSuccess: const AppMessage.CompletedPersistTheme
      }
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
