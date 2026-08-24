module Page.Post.Model where

data CopyStatus
  = NotCopied
  | Copied

type Model =
  { copyStatus :: CopyStatus
  }

initialModel :: Model
initialModel =
  { copyStatus: NotCopied
  }

toString :: CopyStatus -> String
toString status = case status of
  NotCopied -> "Idle"
  Copied -> "Copied"
