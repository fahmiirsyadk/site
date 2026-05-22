module IslandDelegation (initMarkdownProseDelegation) where

import Effect (Effect)
import Data.Unit (Unit)
import Web.DOM.Node (Node)

foreign import initMarkdownProseDelegation :: Node -> Effect Unit
