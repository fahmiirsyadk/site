module Page.Home.Update where

import Page.Home.Command as Command
import Page.Home.Message as Message
import Page.Home.Model as Model

type Result =
  { model :: Model.Model
  , commands :: Array Command.Command
  }

update :: Model.Model -> Message.Message -> Result
update model message = case message of
  Message.SucceededLoadGitHub activity ->
    { model: model { status = Model.Ready activity }
    , commands: []
    }
  Message.FailedLoadGitHub ->
    { model: model { status = Model.Failed }
    , commands: []
    }
  Message.HoveredLab ->
    { model: model { labInteraction = Model.LabHovered }
    , commands: []
    }
  Message.LeftLab ->
    { model: model { labInteraction = Model.LabIdle }
    , commands: []
    }
