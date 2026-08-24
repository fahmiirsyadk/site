module App.Entry where

import Prelude

import App.Core as Core
import App.View as View
import App.Wire.Message as MessageWire
import Effect (Effect)
import Interop.Foldkit.Runtime as Runtime

main :: Effect Unit
main = Runtime.start
  { init: \path -> Core.initInput { path }
  , update: Core.updateInput
  , view: View.view
  , clickedLink: Core.clickedLink
  , changedUrl: Core.changedUrl
  , isKnownMessageTag: Core.isKnownMessageTag
  , messageConstructors: MessageWire.messageConstructors
  }
