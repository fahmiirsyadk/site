module Utils
  ( fetchText
  , afterPaint
  , everyMsInterval
  ) where

import Effect (Effect)
import Data.Unit (Unit)

foreign import fetchText :: String -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit
foreign import afterPaint :: Effect Unit -> Effect Unit
foreign import everyMsInterval :: Int -> Effect Unit -> Effect Unit
