module AnchorNav (scrollToHashId) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, runEffectFn1)

foreign import scrollToHashIdImpl :: EffectFn1 String Unit

scrollToHashId :: String -> Effect Unit
scrollToHashId = runEffectFn1 scrollToHashIdImpl
