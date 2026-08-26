module Page.Post.Model where

import Page.Post.Message as Message

data CopyStatus
  = NotCopied
  | Copied

type Model =
  { copyStatus :: CopyStatus
  , readingProgress :: Message.ReadingProgress
  }

initialModel :: Model
initialModel =
  { copyStatus: NotCopied
  , readingProgress: Message.emptyReadingProgress
  }

toString :: CopyStatus -> String
toString status = case status of
  NotCopied -> "Idle"
  Copied -> "Copied"
