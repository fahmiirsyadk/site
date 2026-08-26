module Page.Post.Update where

import Prelude

import Foldkit.Command as Foldkit
import Page.Post.Command as Command
import Page.Post.Message as Message
import Page.Post.Model as Model

type Result =
  { model :: Model.Model
  , commands :: Array (Foldkit.Command Message.Message)
  }

update :: Model.Model -> Message.Message -> Result
update model message = case message of
  Message.ClickedCopyLink url ->
    { model
    , commands: [ Command.copyLink url ]
    }
  Message.ChangedReadingProgress readingProgress ->
    { model: model { readingProgress = readingProgress }
    , commands: []
    }
  Message.FailedReadingProgress _ ->
    { model
    , commands: []
    }
  Message.MoveProgress delta ->
    { model
    , commands: [ Command.scrollToProgress (clampProgress (model.readingProgress.progress + delta)) ]
    }
  Message.SetProgress progress ->
    { model
    , commands: [ Command.scrollToProgress (clampProgress progress) ]
    }
  Message.CompletedScrollToProgress ->
    { model
    , commands: []
    }
  Message.SucceededCopyLink ->
    { model: model { copyStatus = Model.Copied }
    , commands: [ Command.resetCopyStatus ]
    }
  Message.FailedCopyLink ->
    { model
    , commands: []
    }
  Message.CompletedResetCopyStatus ->
    { model: model { copyStatus = Model.NotCopied }
    , commands: []
    }
  Message.CompletedMountDitheredImage ->
    { model
    , commands: []
    }
  Message.FailedMountDitheredImage ->
    { model
    , commands: []
    }

clampProgress :: Int -> Int
clampProgress progress = max 0 (min 100 progress)
