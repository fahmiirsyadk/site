module App.Wire.Message where

import Prelude

import App.Message as AppMessage
import Data.Array as Array
import Domain.Theme as Theme
import Page.Home.Message as HomeMessage
import Page.Post.Message as Post

type RawFields =
  { _tag :: String
  , requestTag :: String
  , requestUrl :: String
  , requestHref :: String
  , url :: String
  , theme :: String
  , contributions :: Int
  , followers :: Int
  , levels :: Array Int
  }

newtype RawMessage = RawMessage RawFields

messageTags :: Array String
messageTags =
  [ "CompletedNavigateInternal"
  , "FailedNavigateInternal"
  , "StartedRouteEntry"
  , "SucceededLoadGitHub"
  , "FailedLoadGitHub"
  , "HoveredLab"
  , "LeftLab"
  , "ClickedCopyPostLink"
  , "SucceededCopyPostLink"
  , "FailedCopyPostLink"
  , "CompletedResetCopyStatus"
  , "ClickedLink"
  , "ChangedUrl"
  , "LoadedTheme"
  , "SelectedTheme"
  , "CompletedLoadExternal"
  , "CompletedMountSeaShader"
  , "CompletedMountDitheredImage"
  , "CompletedMountHollowMark"
  , "CompletedMountRandomScribble"
  , "CompletedPersistTheme"
  , "CompletedResetScroll"
  , "CompletedSyncDocumentMetadata"
  ]

encode :: AppMessage.Message -> RawMessage
encode message = case message of
  AppMessage.CompletedNavigateInternal -> emptyRaw "CompletedNavigateInternal"
  AppMessage.FailedNavigateInternal -> emptyRaw "FailedNavigateInternal"
  AppMessage.StartedRouteEntry -> emptyRaw "StartedRouteEntry"
  AppMessage.GotHomeMessage (HomeMessage.SucceededLoadGitHub activity) ->
    modifyRaw (emptyRaw "SucceededLoadGitHub") (_ { contributions = activity.contributions, followers = activity.followers, levels = activity.levels })
  AppMessage.GotHomeMessage HomeMessage.FailedLoadGitHub -> emptyRaw "FailedLoadGitHub"
  AppMessage.GotHomeMessage HomeMessage.HoveredLab -> emptyRaw "HoveredLab"
  AppMessage.GotHomeMessage HomeMessage.LeftLab -> emptyRaw "LeftLab"
  AppMessage.ClickedCopyPostLink url -> modifyRaw (emptyRaw "ClickedCopyPostLink") (_ { url = url })
  AppMessage.GotPostMessage (Post.ClickedCopyLink url) -> modifyRaw (emptyRaw "ClickedCopyPostLink") (_ { url = url })
  AppMessage.GotPostMessage Post.SucceededCopyLink -> emptyRaw "SucceededCopyPostLink"
  AppMessage.GotPostMessage Post.FailedCopyLink -> emptyRaw "FailedCopyPostLink"
  AppMessage.GotPostMessage Post.CompletedResetCopyStatus -> emptyRaw "CompletedResetCopyStatus"
  AppMessage.ClickedInternalLink url -> modifyRaw (emptyRaw "ClickedLink") (_ { requestTag = "Internal", requestUrl = url })
  AppMessage.ClickedExternalLink href -> modifyRaw (emptyRaw "ClickedLink") (_ { requestTag = "External", requestHref = href })
  AppMessage.ChangedUrl url -> modifyRaw (emptyRaw "ChangedUrl") (_ { url = url })
  AppMessage.LoadedTheme theme -> modifyRaw (emptyRaw "LoadedTheme") (_ { theme = Theme.toString theme })
  AppMessage.SelectedTheme theme -> modifyRaw (emptyRaw "SelectedTheme") (_ { theme = Theme.toString theme })
  AppMessage.CompletedLoadExternal -> emptyRaw "CompletedLoadExternal"
  AppMessage.CompletedMountSeaShader -> emptyRaw "CompletedMountSeaShader"
  AppMessage.CompletedMountDitheredImage -> emptyRaw "CompletedMountDitheredImage"
  AppMessage.CompletedMountHollowMark -> emptyRaw "CompletedMountHollowMark"
  AppMessage.CompletedMountRandomScribble -> emptyRaw "CompletedMountRandomScribble"
  AppMessage.CompletedPersistTheme -> emptyRaw "CompletedPersistTheme"
  AppMessage.CompletedResetScroll -> emptyRaw "CompletedResetScroll"
  AppMessage.CompletedSyncDocumentMetadata -> emptyRaw "CompletedSyncDocumentMetadata"
  AppMessage.Unknown tag -> emptyRaw tag

decode :: RawMessage -> AppMessage.Message
decode (RawMessage raw) =
  case raw._tag of
    "CompletedNavigateInternal" -> AppMessage.CompletedNavigateInternal
    "FailedNavigateInternal" -> AppMessage.FailedNavigateInternal
    "StartedRouteEntry" -> AppMessage.StartedRouteEntry
    "SucceededLoadGitHub" -> AppMessage.GotHomeMessage (HomeMessage.SucceededLoadGitHub { contributions: raw.contributions, followers: raw.followers, levels: raw.levels })
    "FailedLoadGitHub" -> AppMessage.GotHomeMessage HomeMessage.FailedLoadGitHub
    "HoveredLab" -> AppMessage.GotHomeMessage HomeMessage.HoveredLab
    "LeftLab" -> AppMessage.GotHomeMessage HomeMessage.LeftLab
    "ClickedCopyPostLink" -> AppMessage.ClickedCopyPostLink raw.url
    "SucceededCopyPostLink" -> AppMessage.GotPostMessage Post.SucceededCopyLink
    "FailedCopyPostLink" -> AppMessage.GotPostMessage Post.FailedCopyLink
    "CompletedResetCopyStatus" -> AppMessage.GotPostMessage Post.CompletedResetCopyStatus
    "ClickedLink" -> decodeClickedLink raw
    "ChangedUrl" -> AppMessage.ChangedUrl raw.url
    "LoadedTheme" -> AppMessage.LoadedTheme (Theme.fromString raw.theme)
    "SelectedTheme" -> AppMessage.SelectedTheme (Theme.fromString raw.theme)
    "CompletedLoadExternal" -> AppMessage.CompletedLoadExternal
    "CompletedMountSeaShader" -> AppMessage.CompletedMountSeaShader
    "CompletedMountDitheredImage" -> AppMessage.CompletedMountDitheredImage
    "CompletedMountHollowMark" -> AppMessage.CompletedMountHollowMark
    "CompletedMountRandomScribble" -> AppMessage.CompletedMountRandomScribble
    "CompletedPersistTheme" -> AppMessage.CompletedPersistTheme
    "CompletedResetScroll" -> AppMessage.CompletedResetScroll
    "CompletedSyncDocumentMetadata" -> AppMessage.CompletedSyncDocumentMetadata
    _ -> AppMessage.Unknown raw._tag

clickedCopyPostLink :: String -> RawMessage
clickedCopyPostLink = encode <<< AppMessage.ClickedCopyPostLink

clickedLink :: { requestTag :: String, requestUrl :: String, requestHref :: String } -> RawMessage
clickedLink request = case request.requestTag of
  "Internal" -> encode (AppMessage.ClickedInternalLink request.requestUrl)
  "External" -> encode (AppMessage.ClickedExternalLink request.requestHref)
  _ -> encode (AppMessage.Unknown request.requestTag)

selectedTheme :: Theme.Theme -> RawMessage
selectedTheme = encode <<< AppMessage.SelectedTheme

hoveredLab :: RawMessage
hoveredLab = encode (AppMessage.GotHomeMessage HomeMessage.HoveredLab)

leftLab :: RawMessage
leftLab = encode (AppMessage.GotHomeMessage HomeMessage.LeftLab)

isKnownTag :: String -> Boolean
isKnownTag tag = Array.elem tag messageTags

changedUrl :: String -> RawMessage
changedUrl = encode <<< AppMessage.ChangedUrl

completedNavigateInternal :: RawMessage
completedNavigateInternal = encode AppMessage.CompletedNavigateInternal

failedNavigateInternal :: RawMessage
failedNavigateInternal = encode AppMessage.FailedNavigateInternal

startedRouteEntry :: RawMessage
startedRouteEntry = encode AppMessage.StartedRouteEntry

succeededLoadGitHub :: { contributions :: Int, followers :: Int, levels :: Array Int } -> RawMessage
succeededLoadGitHub activity = encode (AppMessage.GotHomeMessage (HomeMessage.SucceededLoadGitHub activity))

failedLoadGitHub :: RawMessage
failedLoadGitHub = encode (AppMessage.GotHomeMessage HomeMessage.FailedLoadGitHub)

succeededCopyPostLink :: RawMessage
succeededCopyPostLink = encode (AppMessage.GotPostMessage Post.SucceededCopyLink)

failedCopyPostLink :: RawMessage
failedCopyPostLink = encode (AppMessage.GotPostMessage Post.FailedCopyLink)

completedResetCopyStatus :: RawMessage
completedResetCopyStatus = encode (AppMessage.GotPostMessage Post.CompletedResetCopyStatus)

loadedTheme :: String -> RawMessage
loadedTheme = encode <<< AppMessage.LoadedTheme <<< Theme.fromString

completedLoadExternal :: RawMessage
completedLoadExternal = encode AppMessage.CompletedLoadExternal

completedMountSeaShader :: RawMessage
completedMountSeaShader = encode AppMessage.CompletedMountSeaShader

completedMountDitheredImage :: RawMessage
completedMountDitheredImage = encode AppMessage.CompletedMountDitheredImage

completedMountHollowMark :: RawMessage
completedMountHollowMark = encode AppMessage.CompletedMountHollowMark

completedMountRandomScribble :: RawMessage
completedMountRandomScribble = encode AppMessage.CompletedMountRandomScribble

completedPersistTheme :: RawMessage
completedPersistTheme = encode AppMessage.CompletedPersistTheme

completedResetScroll :: RawMessage
completedResetScroll = encode AppMessage.CompletedResetScroll

completedSyncDocumentMetadata :: RawMessage
completedSyncDocumentMetadata = encode AppMessage.CompletedSyncDocumentMetadata

type MessageConstructors =
  { completedNavigateInternal :: RawMessage
  , failedNavigateInternal :: RawMessage
  , startedRouteEntry :: RawMessage
  , succeededLoadGitHub :: { contributions :: Int, followers :: Int, levels :: Array Int } -> RawMessage
  , failedLoadGitHub :: RawMessage
  , succeededCopyPostLink :: RawMessage
  , failedCopyPostLink :: RawMessage
  , completedResetCopyStatus :: RawMessage
  , loadedTheme :: String -> RawMessage
  , completedLoadExternal :: RawMessage
  , completedMountSeaShader :: RawMessage
  , completedMountDitheredImage :: RawMessage
  , completedMountHollowMark :: RawMessage
  , completedMountRandomScribble :: RawMessage
  , completedPersistTheme :: RawMessage
  , completedResetScroll :: RawMessage
  , completedSyncDocumentMetadata :: RawMessage
  }

messageConstructors :: MessageConstructors
messageConstructors =
  { completedNavigateInternal
  , failedNavigateInternal
  , startedRouteEntry
  , succeededLoadGitHub
  , failedLoadGitHub
  , succeededCopyPostLink
  , failedCopyPostLink
  , completedResetCopyStatus
  , loadedTheme
  , completedLoadExternal
  , completedMountSeaShader
  , completedMountDitheredImage
  , completedMountHollowMark
  , completedMountRandomScribble
  , completedPersistTheme
  , completedResetScroll
  , completedSyncDocumentMetadata
  }

emptyRaw :: String -> RawMessage
emptyRaw tag =
  RawMessage { _tag: tag
  , requestTag: ""
  , requestUrl: ""
  , requestHref: ""
  , url: ""
  , theme: ""
  , contributions: 0
  , followers: 0
  , levels: []
  }

decodeClickedLink :: RawFields -> AppMessage.Message
decodeClickedLink raw = case raw.requestTag of
  "Internal" -> AppMessage.ClickedInternalLink raw.requestUrl
  "External" -> AppMessage.ClickedExternalLink raw.requestHref
  _ -> AppMessage.Unknown raw._tag

modifyRaw :: RawMessage -> (RawFields -> RawFields) -> RawMessage
modifyRaw (RawMessage raw) updateFields = RawMessage (updateFields raw)
