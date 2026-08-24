module Page.Home.Model where

type Activity =
  { contributions :: Int
  , followers :: Int
  , levels :: Array Int
  }

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
