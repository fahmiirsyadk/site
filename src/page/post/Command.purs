module Page.Post.Command where

import Prelude

import App.Site as Site
import Foldkit.Clipboard as Clipboard
import Foldkit.Command as Foldkit
import Foldkit.Media as Media
import Foldkit.Render as Render
import Page.Post.Message as Message
import Platform.Browser.Scroll as Scroll
import Platform.Effect as PE
import PursTs.Effect as Fx

copyLink :: String -> Foldkit.Command Message.Message
copyLink url = Foldkit.named "CopyPostLink" { url } \_ ->
  Fx.match (Clipboard.writeText url)
    { onFailure: const Message.FailedCopyLink
    , onSuccess: const Message.SucceededCopyLink
    }

resetCopyStatus :: Foldkit.Command Message.Message
resetCopyStatus = Foldkit.namedNoArgs "ResetCopyStatus" \_ -> do
  PE.delay (PE.Milliseconds 2000)
  Fx.succeed Message.CompletedResetCopyStatus

scrollToProgress :: Int -> Foldkit.Command Message.Message
scrollToProgress progress = Foldkit.named "ScrollToProgress" { progress } \_ -> do
  Render.afterPaint
  reduceMotion <- Media.prefersReducedMotion
  Scroll.scrollToProgress Site.contentScrollSelector progress (not reduceMotion)
  pure Message.CompletedScrollToProgress
