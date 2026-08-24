module Page.Home.Message where

import Page.Home.Model as Model

data Message
  = SucceededLoadGitHub Model.Activity
  | FailedLoadGitHub
  | HoveredLab
  | LeftLab
