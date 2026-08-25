module App.Entry where

import Prelude

import App.Core as Core
import App.View as View
import Foldkit.Runtime as Runtime
import PursTs.Effect as Fx

main :: Fx.Effect Fx.Never Fx.NoServices Unit
main = Runtime.run
  { init: Core.init <<< Core.urlPath
  , update: Core.update
  , view: View.view
  , onUrlRequest: Core.clickedLink
  , onUrlChange: Core.changedUrl
  }
