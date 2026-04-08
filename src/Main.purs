module Main where

import Prelude

import App as SiteApp
import AnchorNav (scrollToHashId)
import Components.Logo (mountCubeLogo)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Effect (Effect)
import Effect.Console (warn)
import Effect.Exception (try)
import Luna.App as LunaApp
import Luna.Html.ModelState (deserializeModelWithDefault)
import Luna.Interpreter (merge, never)
import Luna.Routing as Routing
import RouteInput (setupRouteInputs)
import Routes (lunaRouteCodec, parseRoutePath)
import TocActive (setupScrollSpy)
import Types (Route(..), emptySiteManifest)
import Web.DOM.Element (toNode) as DOMElement
import Web.DOM.Node (setTextContent) as DOMNode
import Web.DOM.ParentNode (QuerySelector(..), querySelector) as DOM
import Web.HTML (window)
import Web.HTML.Location as Location
import Web.HTML.HTMLDocument (toParentNode) as HTMLDocument
import Web.HTML.Window (document)
import Web.HTML.Window (location) as Window

main :: Effect Unit
main = do
  win <- window
  doc <- document win
  mbAppRoot <- DOM.querySelector (DOM.QuerySelector "#app") (HTMLDocument.toParentNode doc)
  case mbAppRoot of
    Nothing -> pure unit
    Just appRoot -> do
      manifest <- deserializeModelWithDefault emptySiteManifest
      loc <- Window.location win
      path <- Location.pathname loc
      let
        initialRoute = case parseRoutePath path of
          Nothing -> Home
          Just route -> route
        appRootNode = DOMElement.toNode appRoot
        initialModel =
          { route: initialRoute
          , manifest
          , activeTocId: Nothing
          }
      hydrateResult <- try (LunaApp.makeHydrate (never `merge` never) (SiteApp.app initialModel) appRootNode)
      inst <- case hydrateResult of
        Right i -> pure i
        Left _ -> do
          warn "Hydration failed, falling back to full render"
          DOMNode.setTextContent "" appRootNode
          LunaApp.make (never `merge` never) (SiteApp.app initialModel) appRootNode
      _ <- setupRouteInputs
        appRootNode
        lunaRouteCodec
        Routing.PathRouting
        (\maybeRoute -> inst.pushAndRun (SiteApp.RouteChanged maybeRoute))
        (\path' -> inst.pushAndRun (SiteApp.NavigatePath path'))
        (\id -> inst.pushAndRun (SiteApp.SetActiveToc id))
      mountCubeLogo
      inst.run
      setupScrollSpy "content-scroll" \maybeId ->
        case maybeId of
          Nothing -> pure unit
          Just id -> inst.pushAndRun (SiteApp.SetActiveToc id)
      hash <- Location.hash loc
      when (String.length hash > 1) do
        let id = String.drop 1 hash
        inst.pushAndRun (SiteApp.SetActiveToc id)
        scrollToHashId id