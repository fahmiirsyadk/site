module Main where

import Prelude

import App as SiteApp
import AnchorNav (scrollToHashId)
import Components.Logo (mountCubeLogo)
import Data.Either (Either(..), either)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Data.String as String
import Effect (Effect)
import Effect.Console (warn)
import Effect.Exception (try)
import Effect.Ref as Ref
import ManifestCodec (decodeSiteManifestString)
import Luna.App as LunaApp
import Luna.Html.ModelState (deserializeModelWithDefault)
import Luna.Interpreter (merge, never)
import Luna.Routing as Routing
import RouteInput (setupRouteInputs)
import Routes (lunaRouteCodec, parseRoutePath)
import TocActive (setupScrollSpy)
import Types (Route(..), emptySiteManifest)
import Web.DOM.Element (toNode) as DOMElement
import Web.DOM.Node (Node, setTextContent) as DOMNode
import Web.DOM.ParentNode (QuerySelector(..), querySelector) as DOM
import Web.HTML (window)
import Web.HTML.Location as Location
import Web.HTML.HTMLDocument (toParentNode) as HTMLDocument
import Web.HTML.Window (document)
import Web.HTML.Window (location) as Window

foreign import fetchText :: String -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit

main :: Effect Unit
main = do
  win <- window
  doc <- document win
  mbAppRoot <- DOM.querySelector (DOM.QuerySelector "#app") (HTMLDocument.toParentNode doc)
  for_ mbAppRoot \appRoot -> startClient (DOMElement.toNode appRoot)

startClient :: DOMNode.Node -> Effect Unit
startClient appRootNode = do
  manifest <- deserializeModelWithDefault emptySiteManifest
  win <- window
  loc <- Window.location win
  path <- Location.pathname loc
  let
    initialRoute = case parseRoutePath path of
      Nothing -> Home
      Just route -> route
    initialModel =
      { route: initialRoute
      , manifest
      , activeTocId: Nothing
      }
    app = SiteApp.app initialModel
    interpreter = never `merge` never
  hydrateResult <- try (LunaApp.makeHydrate interpreter app appRootNode)
  inst <-
    either
      (\_ -> do
        warn "Hydration failed, falling back to full render"
        DOMNode.setTextContent "" appRootNode
        LunaApp.make interpreter app appRootNode)
      pure
      hydrateResult
  hasFullManifestRef <- Ref.new false
  let
    ensureFullManifest :: Effect Unit -> Effect Unit
    ensureFullManifest continue = do
      loaded <- Ref.read hasFullManifestRef
      if loaded then
        continue
      else
        fetchText
          "/site-manifest.json"
          (\raw -> do
            case decodeSiteManifestString raw of
              Left err -> warn err
              Right fullManifest -> do
                Ref.write true hasFullManifestRef
                inst.pushAndRun (SiteApp.ReplaceManifest fullManifest)
            continue
          )
          (\err -> do
            warn $ "Failed to load site-manifest.json: " <> err
            continue
          )
  _ <-
    setupRouteInputs
      appRootNode
      lunaRouteCodec
      Routing.PathRouting
      (\maybeRoute ->
        case maybeRoute of
          Just (SectionPost _ _) -> ensureFullManifest (inst.pushAndRun (SiteApp.RouteChanged maybeRoute))
          _ -> inst.pushAndRun (SiteApp.RouteChanged maybeRoute)
      )
      (\path' ->
        case parseRoutePath path' of
          Just (SectionPost _ _) -> ensureFullManifest (inst.pushAndRun (SiteApp.NavigatePath path'))
          _ -> inst.pushAndRun (SiteApp.NavigatePath path')
      )
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
