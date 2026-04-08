module LinkInterceptor (interceptLinks) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn3, runEffectFn3)
import Web.DOM.Node (Node)

foreign import interceptLinksImpl :: EffectFn3 Node (String -> Effect Unit) (String -> Effect Unit) (Effect Unit)

interceptLinks :: Node -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect (Effect Unit)
interceptLinks = runEffectFn3 interceptLinksImpl
