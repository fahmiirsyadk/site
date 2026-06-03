module Main where

import Prelude

import ClientApp (startClient)
import Data.Foldable (any)
import Data.Maybe (Maybe(..), isJust)
import Data.String.CodeUnits as SCU
import Data.String.Pattern (Pattern(..))
import Effect (Effect)
import Effect.Console (warn)
import Web.DOM.Element (toNode) as DOMElement
import Web.DOM.ParentNode (QuerySelector(..), querySelector) as DOM
import Web.HTML (window)
import Web.HTML.HTMLDocument (toParentNode) as HTMLDocument
import Web.HTML.Window (document)

foreign import mountSeaFooter :: Effect Unit
foreign import gfxBootCheckNoCubeHosts :: Effect Unit
foreign import setupTocHashSync :: (String -> Effect Unit) -> Effect Unit

toolingHydrateAttributesIgnore :: String -> Boolean
toolingHydrateAttributesIgnore name =
  name == "data-cursor-ref"
    || any (\p -> isJust (SCU.stripPrefix (Pattern p) name))
      [ "data-cursor-", "data-cf-", "data-grammarly-", "data-gr-ext", "data-new-gr-" ]

main :: Effect Unit
main = do
  win <- window
  doc <- document win
  mbAppRoot <- DOM.querySelector (DOM.QuerySelector "#app") (HTMLDocument.toParentNode doc)
  case mbAppRoot of
    Nothing -> warn "Could not find #app root; client app not started"
    Just appRoot ->
      startClient
        { mountSeaFooter
        , gfxBootCheckNoCubeHosts
        , setupTocHashSync
        , hydrateAttributesIgnore: toolingHydrateAttributesIgnore
        }
        (DOMElement.toNode appRoot)
