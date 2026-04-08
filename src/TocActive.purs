module TocActive (setupScrollSpy) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, runEffectFn2)

foreign import setupScrollSpyImpl :: EffectFn2 String (Nullable String -> Effect Unit) Unit

setupScrollSpy :: String -> (Maybe String -> Effect Unit) -> Effect Unit
setupScrollSpy scrollContainerId callback =
  runEffectFn2 setupScrollSpyImpl scrollContainerId (\nullable -> callback (toMaybe nullable))
