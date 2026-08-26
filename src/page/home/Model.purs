module Page.Home.Model where

import Domain.GitHub as GitHub

type Activity = GitHub.Activity

data Status
  = Loading
  | Failed
  | Ready Activity

data LabInteraction
  = LabIdle
  | LabHovered

type Model =
  { status :: Status
  , labInteraction :: LabInteraction
  }

initialModel :: Model
initialModel =
  { status: Loading
  , labInteraction: LabIdle
  }

labInteractionName :: LabInteraction -> String
labInteractionName interaction = case interaction of
  LabIdle -> "idle"
  LabHovered -> "hovered"
