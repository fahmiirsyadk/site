module Measure (measureToolCards) where

import Effect (Effect)
import Data.Unit (Unit)

foreign import measureToolCards :: (String -> Int -> Effect Unit) -> Effect Unit
