module App.Message where

import Domain.Theme as Theme
import Page.Home.Message as HomeMessage
import Page.Post.Message as Post

data Message
  = CompletedNavigateInternal
  | StartedRouteEntry
  | GotHomeMessage HomeMessage.Message
  | ClickedCopyPostLink String
  | GotPostMessage Post.Message
  | ClickedInternalLink String
  | ClickedExternalLink String
  | ChangedUrl String
  | LoadedTheme Theme.Theme
  | SelectedTheme Theme.Theme
  | CompletedLoadExternal
  | CompletedMountSeaShader
  | CompletedMountHollowMark
  | CompletedMountRandomScribble
  | FailedMountSeaShader
  | FailedMountHollowMark
  | FailedMountRandomScribble
  | CompletedPersistTheme
  | FailedPersistTheme
  | CompletedResetScroll
  | FailedResetScroll
  | CompletedSyncDocumentMetadata
  | FailedSyncDocumentMetadata
