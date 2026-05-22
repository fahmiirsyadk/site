module Theme
  ( getStoredThemeMode
  , applyThemeMode
  , patchSsrThemeButtons
  ) where

import Effect (Effect)
import Data.Unit (Unit)

foreign import getStoredThemeMode :: Effect String
foreign import applyThemeMode :: String -> Effect Unit
foreign import patchSsrThemeButtons :: String -> Effect Unit
