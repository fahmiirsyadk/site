module TocActive (setupScrollSpy, tickScrollSpy) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)

foreign import setupScrollSpyImpl :: EffectFn2 String (Nullable String -> Effect Unit) Unit

foreign import tickScrollSpyImpl :: EffectFn1 String Unit

setupScrollSpy :: String -> (Maybe String -> Effect Unit) -> Effect Unit
setupScrollSpy scrollContainerId callback =
  runEffectFn2 setupScrollSpyImpl scrollContainerId (\nullable -> callback (toMaybe nullable))

-- | Re-run after article HTML is patched (e.g. lazy JSON body) so headings exist before scroll events.
tickScrollSpy :: String -> Effect Unit
tickScrollSpy containerId = runEffectFn1 tickScrollSpyImpl containerId
