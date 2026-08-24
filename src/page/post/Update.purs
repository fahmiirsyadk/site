module Page.Post.Update where

import Page.Post.Command as Command
import Page.Post.Message as Message
import Page.Post.Model as Model

type Result =
  { model :: Model.Model
  , commands :: Array Command.Command
  }

update :: Model.Model -> Message.Message -> Result
update model message = case message of
  Message.ClickedCopyLink url ->
    { model
    , commands: [ Command.CopyLink url ]
    }
  Message.SucceededCopyLink ->
    { model: model { copyStatus = Model.Copied }
    , commands: [ Command.ResetCopyStatus ]
    }
  Message.FailedCopyLink ->
    { model
    , commands: []
    }
  Message.CompletedResetCopyStatus ->
    { model: model { copyStatus = Model.NotCopied }
    , commands: []
    }
