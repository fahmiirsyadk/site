module Page.Post.Message where

data Message
  = ClickedCopyLink String
  | SucceededCopyLink
  | FailedCopyLink
  | CompletedResetCopyStatus
  | CompletedMountDitheredImage
