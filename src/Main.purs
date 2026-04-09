module Main where

import Prelude

import App as SiteApp
import AnchorNav (scrollToHashId)
import Components.Logo (mountCubeLogo)
import Data.Argonaut.Decode (decodeJson) as AD
import Data.Argonaut.Parser (jsonParser) as Parser
import Data.Bifunctor (lmap)
import Data.Either (Either(..), either)
import Data.Set as Set
import Data.Maybe (Maybe(..))
import Data.String as String
import Effect (Effect)
import Effect.Console (warn)
import Effect.Exception (try)
import Effect.Ref as Ref
import Luna.App as LunaApp
import Luna.Html.ModelState (deserializeModelWithDefault)
import Luna.Interpreter (merge, never)
import Luna.Routing as Routing
import RouteInput (setupRouteInputs)
import Routes (lunaRouteCodec, parseRoutePath)
import TocActive (setupScrollSpy)
import Types (Route(..), TocItem, emptySiteManifest)
import Web.DOM.Element (toNode) as DOMElement
import Web.DOM.Node (Node) as DOMNode
import Web.DOM.ParentNode (QuerySelector(..), querySelector) as DOM
import Web.HTML (window)
import Web.HTML.Location as Location
import Web.HTML.HTMLDocument (toParentNode) as HTMLDocument
import Web.HTML.Window (document)
import Web.HTML.Window (location) as Window

foreign import fetchText :: String -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit

data ManifestState
  = NotRequested
  | Loading String
  | Failed String

type PostContentPayload =
  { section :: String
  , slug :: String
  , bodyHtml :: String
  , toc :: Array TocItem
  }

type PostContentFetchState =
  { loaded :: Set.Set String
  , failed :: Set.Set String
  }

needsFullManifest :: Maybe Route -> Boolean
needsFullManifest (Just (SectionPost _ _)) = true
needsFullManifest _ = false

postKey :: String -> String -> String
postKey section slug = section <> "/" <> slug

postPayloadUrl :: String -> String -> String
postPayloadUrl section slug = "/data/posts/" <> section <> "/" <> slug <> ".json"

decodePostContentPayload :: String -> Either String PostContentPayload
decodePostContentPayload raw = do
  json <- Parser.jsonParser raw
  lmap show (AD.decodeJson json)

main :: Effect Unit
main = do
  win <- window
  doc <- document win
  mbAppRoot <- DOM.querySelector (DOM.QuerySelector "#app") (HTMLDocument.toParentNode doc)
  case mbAppRoot of
    Nothing -> warn "Could not find #app root; client app not started"
    Just appRoot -> startClient (DOMElement.toNode appRoot)

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
        LunaApp.make interpreter app appRootNode)
      pure
      hydrateResult
  postContentStateRef <- Ref.new { loaded: Set.empty, failed: Set.empty }
  manifestStateRef <- Ref.new NotRequested
  case initialRoute of
    SectionPost section slug ->
      Ref.modify_ (\st -> st { loaded = Set.insert (postKey section slug) st.loaded }) postContentStateRef
    _ -> pure unit
  let
    ensurePostContent :: String -> String -> Effect Unit -> Effect Unit
    ensurePostContent section slug continue = do
      let key = postKey section slug
      postContentState <- Ref.read postContentStateRef
      if Set.member key postContentState.loaded then
        continue
      else if Set.member key postContentState.failed then
        warn $ "Post content is unavailable for " <> key <> "; staying on current page."
      else do
        manifestState <- Ref.read manifestStateRef
        case manifestState of
          Loading loadingKey | loadingKey == key -> pure unit
          _ -> do
            Ref.write (Loading key) manifestStateRef
            fetchText
              (postPayloadUrl section slug)
              (\raw -> do
                case decodePostContentPayload raw of
                  Left err -> do
                    Ref.write (Failed key) manifestStateRef
                    Ref.modify_ (\st -> st { failed = Set.insert key st.failed }) postContentStateRef
                    warn $ "Failed to decode post payload for " <> key <> ": " <> err
                  Right payload -> do
                    Ref.write NotRequested manifestStateRef
                    Ref.modify_ (\st -> st { loaded = Set.insert key st.loaded }) postContentStateRef
                    inst.pushAndRun (SiteApp.MergePostContent payload)
                    continue
              )
              (\err -> do
                Ref.write (Failed key) manifestStateRef
                Ref.modify_ (\st -> st { failed = Set.insert key st.failed }) postContentStateRef
                warn $ "Failed to load post payload for " <> key <> ": " <> err
              )

    ensureRouteContent :: Maybe Route -> Effect Unit -> Effect Unit
    ensureRouteContent maybeRoute continue =
      case maybeRoute of
        Just (SectionPost section slug) -> ensurePostContent section slug continue
        _ -> continue

    ensurePathContent :: String -> Effect Unit -> Effect Unit
    ensurePathContent path' continue =
      case parseRoutePath path' of
        Just (SectionPost section slug) -> ensurePostContent section slug continue
        _ -> continue

  mountCubeLogo
  inst.run
  _ <-
    setupRouteInputs
      appRootNode
      lunaRouteCodec
      Routing.PathRouting
      (\maybeRoute ->
        if needsFullManifest maybeRoute then
          ensureRouteContent maybeRoute (inst.pushAndRun (SiteApp.RouteChanged maybeRoute))
        else
          inst.pushAndRun (SiteApp.RouteChanged maybeRoute)
      )
      (\path' ->
        if needsFullManifest (parseRoutePath path') then
          ensurePathContent path' (inst.pushAndRun (SiteApp.NavigatePath path'))
        else
          inst.pushAndRun (SiteApp.NavigatePath path')
      )
      (\id -> inst.pushAndRun (SiteApp.SetActiveToc id))
  setupScrollSpy "content-scroll" \maybeId ->
    case maybeId of
      Nothing -> pure unit
      Just id -> inst.pushAndRun (SiteApp.SetActiveToc id)
  hash <- Location.hash loc
  when (String.length hash > 1) do
    let id = String.drop 1 hash
    inst.pushAndRun (SiteApp.SetActiveToc id)
    scrollToHashId id
