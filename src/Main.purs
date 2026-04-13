module Main where

import Prelude

import App as SiteApp
import AnchorNav (scrollToHashId)
import Components.Banner (disposeBannerIfAny, mountBannerFilter)
import Components.Banner.FFI (BannerHandle)
import Components.Logo (mountCubeLogo)
import Defer (runWhenIdle)
import Data.Argonaut.Decode (decodeJson, (.:), (.!=), (.:?))
import Data.Argonaut.Decode.Error (printJsonDecodeError)
import Data.Argonaut.Parser (jsonParser) as Parser
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Foldable (any)
import Data.Maybe (Maybe(..), isJust)
import Data.Set as Set
import Data.String as String
import Data.String.CodeUnits as SCU
import Data.String.Pattern (Pattern(..))
import Effect (Effect)
import Effect.Console (warn)
import Effect.Ref as Ref
import Luna.App (HydrationBootstrapOptions, makeHydrateOrBuild)
import Luna.Html.ModelState (deserializeModelWithDefault)
import Luna.Interpreter (merge, never)
import Luna.Routing as Routing
import RouteInput (setupRouteInputs)
import Routes (lunaRouteCodec, parseRoutePath)
import TocActive (setupScrollSpy, tickScrollSpy)
import Data.Map as Map
import Types (BodyBlock, Route(..), SiteManifest, TocItem, emptySiteManifest)
import Web.DOM.Element (toNode) as DOMElement
import Web.DOM.Node (Node) as DOMNode
import Web.DOM.ParentNode (QuerySelector(..), querySelector) as DOM
import Web.HTML (window)
import Web.HTML.Location as Location
import Web.HTML.HTMLDocument (toParentNode) as HTMLDocument
import Web.HTML.Window (document)
import Web.HTML.Window (location) as Window

foreign import fetchText :: String -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit
foreign import mountSeaFooter :: Effect Unit
foreign import gfxBootCheckNoCubeHosts :: Effect Unit
foreign import getStoredThemeMode :: Effect String
foreign import patchSsrThemeButtons :: String -> Effect Unit
foreign import applyThemeMode :: String -> Effect Unit
foreign import measureToolCards :: (String -> Int -> Effect Unit) -> Effect Unit
foreign import initMarkdownProseDelegation :: DOMNode.Node -> Effect Unit

-- | Fire `eff` every `ms` milliseconds
foreign import everyMsInterval :: Int -> Effect Unit -> Effect Unit

-- | Run `eff` after the next paint frame (rAF), ensuring VDOM patches are visible.
foreign import afterPaint :: Effect Unit -> Effect Unit

foreign import setupTocHashSync :: (String -> Effect Unit) -> Effect Unit

-- | Tooling-injected `data-*` names Halogen hydration would otherwise reject (see Luna `hydrateAttributesIgnore`).
toolingHydrateAttributesIgnore :: String -> Boolean
toolingHydrateAttributesIgnore name =
  name == "data-cursor-ref"
    || any (\p -> isJust (SCU.stripPrefix (Pattern p) name))
      [ "data-cursor-", "data-cf-", "data-grammarly-", "data-gr-ext", "data-new-gr-" ]

data ManifestState
  = NotRequested
  | Loading String
  | Failed String

type PostContentPayload =
  { section :: String
  , slug :: String
  , bodyHtml :: String
  , bodyBlocks :: Array BodyBlock
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
  lmap printJsonDecodeError do
    o <- decodeJson json
    section <- o .: "section"
    slug <- o .: "slug"
    bodyHtml <- o .: "bodyHtml"
    bodyBlocks <- o .:? "bodyBlocks" .!= ([] :: Array BodyBlock)
    toc <- o .: "toc"
    pure { section, slug, bodyHtml, bodyBlocks, toc }

postHasBodyBlocks :: SiteManifest -> String -> String -> Boolean
postHasBodyBlocks m section slug =
  case Array.find (\p -> p.section == section && p.slug == slug) m.posts of
    Nothing -> false
    Just p -> not (Array.null p.bodyBlocks)

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
  initMarkdownProseDelegation appRootNode
  manifest <- deserializeModelWithDefault emptySiteManifest
  win <- window
  loc <- Window.location win
  path <- Location.pathname loc
  let
    initialRoute = case parseRoutePath path of
      Nothing -> Home
      Just route -> route
  storedTheme <- getStoredThemeMode
  let
    hydrationOpts :: HydrationBootstrapOptions
    hydrationOpts =
      { hydrateAttributesIgnore: toolingHydrateAttributesIgnore
      , beforeHydrate: Just (\_ -> patchSsrThemeButtons storedTheme)
      }
    initialModel =
      { route: initialRoute
      , manifest: manifest
      , activeTocId: Nothing
      , useRelativeDates: false
      , relativeTimeTick: 0
      , themeMode: storedTheme
      , terminalExpanded: Map.empty
      , toolCards: Map.empty
      }
    app = SiteApp.app initialModel
    interpreter = never `merge` never
  inst <- makeHydrateOrBuild interpreter app appRootNode hydrationOpts
  void $
    inst.subscribe \ch ->
      when (ch.old.themeMode /= ch.new.themeMode) do
        applyThemeMode ch.new.themeMode
  bannerHandleRef <- Ref.new Nothing :: Effect (Ref.Ref (Maybe BannerHandle))
  postContentStateRef <- Ref.new { loaded: Set.empty, failed: Set.empty }
  manifestStateRef <- Ref.new NotRequested
  case initialRoute of
    SectionPost section slug
      | postHasBodyBlocks manifest section slug ->
        Ref.modify_ (\st -> st { loaded = Set.insert (postKey section slug) st.loaded }) postContentStateRef
    _ -> pure unit
  let
    syncBannerForRoute :: Maybe Route -> Effect Unit
    syncBannerForRoute maybeRoute =
      case maybeRoute of
        Just (SectionPost section slug) -> do
          let
            mbPost = Array.find (\p -> p.slug == slug && p.section == section) manifest.posts
            bannerSrc = case mbPost of
              Just p | String.length p.banner > 0 -> p.banner
              _ -> "/assets/banners/" <> slug <> ".png"
          cur <- Ref.read bannerHandleRef
          next <- mountBannerFilter cur bannerSrc
          Ref.write next bannerHandleRef
        _ -> do
          cur <- Ref.read bannerHandleRef
          next <- disposeBannerIfAny cur
          Ref.write next bannerHandleRef

    syncArticleChrome :: Maybe Route -> Effect Unit
    syncArticleChrome maybeRoute =
      afterPaint do
        tickScrollSpy "content-scroll"
        runWhenIdle do
          syncBannerForRoute maybeRoute
          measureToolCards \id h -> inst.pushAndRun (SiteApp.ToolCardMeasured id h)

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
                    afterPaint do
                      tickScrollSpy "content-scroll"
                      runWhenIdle (measureToolCards \id h -> inst.pushAndRun (SiteApp.ToolCardMeasured id h))
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

  -- Sea: `mountSeaFooter` + `gfx-boot-pause-for-sea` start compile during boot pause; if overlay is absent, idle-mount runs immediately.
  mountSeaFooter
  mountCubeLogo
  gfxBootCheckNoCubeHosts
  inst.run
  applyThemeMode storedTheme
  -- VDOM: switch post dates from calendar (hydration-safe) to Intl relative time.
  inst.pushAndRun SiteApp.EnableRelativeDates
  case initialRoute of
    SectionPost section slug
      | not (postHasBodyBlocks manifest section slug) ->
        ensurePostContent section slug do pure unit
    _ -> pure unit
  syncArticleChrome (Just initialRoute)
  -- Re-render once per minute so "8h ago" etc.
  everyMsInterval 60000 (inst.pushAndRun SiteApp.TickRelativeDates)
  _ <-
    setupRouteInputs
      appRootNode
      lunaRouteCodec
      Routing.PathRouting
      (\maybeRoute ->
        if needsFullManifest maybeRoute then
          ensureRouteContent maybeRoute do
            inst.pushAndRun (SiteApp.RouteChanged maybeRoute)
            syncArticleChrome maybeRoute
        else
          do
            inst.pushAndRun (SiteApp.RouteChanged maybeRoute)
            syncArticleChrome maybeRoute
      )
      (\path' ->
        let
          route = parseRoutePath path'
        in
          if needsFullManifest route then
            ensurePathContent path' do
              inst.pushAndRun (SiteApp.NavigatePath path')
              syncArticleChrome route
          else
            do
              inst.pushAndRun (SiteApp.NavigatePath path')
              syncArticleChrome route
      )
      (\id -> inst.pushAndRun (SiteApp.SetActiveToc id))
  setupScrollSpy "content-scroll" \maybeId ->
    case maybeId of
      Nothing -> pure unit
      Just id -> inst.pushAndRun (SiteApp.SetActiveToc id)
  setupTocHashSync \hashFrag -> inst.pushAndRun (SiteApp.SetActiveToc hashFrag)
  hash <- Location.hash loc
  when (String.length hash > 1) do
    let id = String.drop 1 hash
    inst.pushAndRun (SiteApp.SetActiveToc id)
    scrollToHashId id