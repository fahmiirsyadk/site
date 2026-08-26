module App.Mount where

import Prelude

import App.Message as AppMessage
import Foldkit.Mount (MountAction)
import Foldkit.Mount as Mount
import Page.Post.Message as PostMessage
import Platform.Browser as Browser
import Platform.Browser.Scroll as Scroll
import PursTs.Effect as Fx
import Runtime.Scroll as RuntimeScroll

mount
  :: forall message
   . (Mount.Element -> Fx.Effect Browser.BrowserError Fx.NoServices Browser.Cleanup)
  -> message
  -> message
  -> Mount.Element
  -> Fx.Effect Fx.Never Fx.Scope message
mount acquire completed failed element =
  Fx.catchAll
    (Fx.as completed (Fx.acquireRelease (acquire element) Browser.release))
    (const (Fx.succeed failed))

ditheredImage :: MountAction PostMessage.Message
ditheredImage = Mount.define "DitheredImage"
  (mount Browser.acquireDitheredImage
    PostMessage.CompletedMountDitheredImage
    PostMessage.FailedMountDitheredImage)

hollowMark :: MountAction AppMessage.Message
hollowMark = Mount.define "HollowMark"
  (mount Browser.acquireHollowMark
    AppMessage.CompletedMountHollowMark
    AppMessage.FailedMountHollowMark)

randomScribble :: MountAction AppMessage.Message
randomScribble = Mount.define "RandomScribble"
  (mount Browser.acquireRandomScribble
    AppMessage.CompletedMountRandomScribble
    AppMessage.FailedMountRandomScribble)

seaShader :: MountAction AppMessage.Message
seaShader = Mount.define "SeaShader"
  (mount Browser.acquireSeaShader
    AppMessage.CompletedMountSeaShader
    AppMessage.FailedMountSeaShader)

trackPostProgress :: MountAction PostMessage.Message
trackPostProgress = Scroll.trackReadingProgress
  "TrackPostProgress"
  { scrollRootSelector: "#content-scroll"
  , layoutSelector: "[data-post-layout]"
  , contentSelector: ".post-prose"
  , headingSelector: "h2, h3, h4"
  }
  (\reason -> PostMessage.FailedReadingProgress reason)
  (PostMessage.ChangedReadingProgress <<< RuntimeScroll.readingProgress)
