module App.Command where

import App.Site as Site
import Domain.Content as Content
import Domain.Theme as Theme
import Page.Home.Command as Home
import Page.Post.Command as Post

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
