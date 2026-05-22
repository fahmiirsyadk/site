module RelativeTimePatch (patchRelativeDates) where

import Effect (Effect)
import Data.Unit (Unit)

foreign import patchRelativeDates :: Effect Unit
