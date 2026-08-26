module App.Message where

import Data.Maybe (Maybe)
import Domain.Theme as Theme
import Page.Home.Message as HomeMessage
import Page.Post.Message as Post

data Message
  = CompletedNavigateInternal
  | CompletedNavigateHeading
  | CompletedScrollToHeading
  | CompletedScrollToProgress
  | StartedRouteEntry
  | GotHomeMessage HomeMessage.Message
  | ClickedCopyPostLink String
  | GotPostMessage Post.Message
  | ClickedInternalLink { path :: String, hash :: Maybe String }
  | ClickedExternalLink String
  | ChangedUrl { path :: String, hash :: Maybe String }
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
