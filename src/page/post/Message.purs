module Page.Post.Message where

import Runtime.Scroll as Scroll

type HeadingPosition = Scroll.HeadingPosition

type ReadingProgress = Scroll.ReadingProgress

emptyReadingProgress :: ReadingProgress
emptyReadingProgress =
  { progress: 0
  , headings: []
  }

data Message
  = ClickedCopyLink String
  | ChangedReadingProgress ReadingProgress
  | FailedReadingProgress String
  | MoveProgress Int
  | SetProgress Int
  | CompletedScrollToProgress
  | SucceededCopyLink
  | FailedCopyLink
  | CompletedResetCopyStatus
  | CompletedMountDitheredImage
  | FailedMountDitheredImage
