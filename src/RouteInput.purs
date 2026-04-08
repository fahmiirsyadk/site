module RouteInput (setupRouteInputs) where

import Prelude

import Data.Maybe (Maybe)
import Effect (Effect)
import LinkInterceptor (interceptLinks)
import Luna.Routing as Routing
import Web.DOM.Node (Node)

setupRouteInputs
  :: forall route
   . Node
  -> Routing.RouteCodec route
  -> Routing.RoutingMode
  -> (Maybe route -> Effect Unit)
  -> (String -> Effect Unit)
  -> (String -> Effect Unit)
  -> Effect (Effect Unit)
setupRouteInputs appRoot codec mode onRouteChange onPathNavigate onHashNavigate = do
  unsubscribeRoute <- Routing.subscribeDecodedRouteChanges codec mode onRouteChange
  unsubscribeLinks <- interceptLinks appRoot onPathNavigate onHashNavigate
  pure do
    unsubscribeRoute
    unsubscribeLinks
