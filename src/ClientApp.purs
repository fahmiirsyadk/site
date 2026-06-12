module ClientApp
  ( Config
  , ManifestState(..)
  , PostContentFetchState
  , startClient
  ) where

import Prelude

import App as SiteApp
import Components.Banner (disposeBannerIfAny, mountBannerFilter)
import Components.Banner.FFI (BannerHandle)
import Components.Logo (mountCubeLogo)
import Data.Argonaut.Decode (decodeJson, (.:), (.!=), (.:?))
import Data.Argonaut.Decode.Error (printJsonDecodeError)
import Data.Argonaut.Parser (jsonParser) as Parser
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.String as String
import Effect (Effect)
import Effect.Console (warn)
import Effect.Ref as Ref
import FFI (afterPaint, applyThemeMode, everyMsInterval, fetchText, getStoredThemeMode, initMarkdownProseDelegation, measureToolCards, patchRelativeDates, patchSsrThemeButtons, runWhenIdle, scrollToHashId, setupScrollSpy, tickScrollSpy)
import Luna.App (HydrationBootstrapOptions, makeHydrateOrBuild)
import Luna.Html.ModelState (deserializeModelWithDefault)
import Luna.Interpreter (merge, never)
import Luna.Routing as Routing
import RouteInput (setupRouteInputs)
import Routes (lunaRouteCodec, parseRoutePath)
import Types (BodyBlock, PostContentPayload, Route(..), SiteManifest, emptySiteManifest, findPost, sectionFrom, themeModeFrom, themeModeToString)
import Web.DOM.Node (Node) as DOMNode
import Web.HTML (window)
import Web.HTML.Location as Location
import Web.HTML.Window (location) as Window

type Config =
  { mountSeaFooter :: Effect Unit
  , gfxBootCheckNoCubeHosts :: Effect Unit
  , setupTocHashSync :: (String -> Effect Unit) -> Effect Unit
  , hydrateAttributesIgnore :: String -> Boolean
  }

data ManifestState
  = NotRequested
  | Loading String
  | Failed String

type PostContentFetchState =
  { loaded :: Set.Set String
  , failed :: Set.Set String
  }

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
  case findPost m.posts (sectionFrom section) slug of
    Nothing -> false
    Just p -> not (Array.null p.bodyBlocks)

startClient :: Config -> DOMNode.Node -> Effect Unit
startClient cfg appRootNode = do
  initMarkdownProseDelegation appRootNode
  manifest <- deserializeModelWithDefault emptySiteManifest
  win <- window
  loc <- Window.location win
  path <- Location.pathname loc
  let
    initialRoute = case parseRoutePath path of
      Nothing -> Home
      Just route -> route
  storedThemeStr <- getStoredThemeMode
  let storedTheme = themeModeFrom storedThemeStr
  let
    hydrationOpts :: HydrationBootstrapOptions
    hydrationOpts =
      { hydrateAttributesIgnore: cfg.hydrateAttributesIgnore
      , beforeHydrate: Just (\_ -> patchSsrThemeButtons (themeModeToString storedTheme))
      }
    initialModel =
      { route: initialRoute
      , manifest: manifest
      , activeTocId: Nothing
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
        applyThemeMode (themeModeToString ch.new.themeMode)
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
            mbPost = findPost manifest.posts (sectionFrom section) slug
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

    syncScrollSpy :: Effect Unit
    syncScrollSpy = tickScrollSpy "content-scroll"

    syncToolCardMeasures :: Effect Unit
    syncToolCardMeasures =
      measureToolCards \id h -> inst.pushAndRun (SiteApp.ToolCardMeasured id h)

    syncArticleChrome :: Maybe Route -> Effect Unit
    syncArticleChrome maybeRoute = do
      afterPaint syncScrollSpy
      runWhenIdle do
        syncBannerForRoute maybeRoute
        syncToolCardMeasures

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
                    afterPaint syncScrollSpy
                    runWhenIdle syncToolCardMeasures
                    continue
              )
              (\err -> do
                Ref.write (Failed key) manifestStateRef
                Ref.modify_ (\st -> st { failed = Set.insert key st.failed }) postContentStateRef
                warn $ "Failed to load post payload for " <> key <> ": " <> err
              )

    routeNeedsPostContent :: Maybe Route -> Maybe { section :: String, slug :: String }
    routeNeedsPostContent = case _ of
      Just (SectionPost section slug) -> Just { section, slug }
      _ -> Nothing

    withRouteContent :: Maybe Route -> Effect Unit -> Effect Unit
    withRouteContent maybeRoute continue =
      case routeNeedsPostContent maybeRoute of
        Just { section, slug } -> ensurePostContent section slug continue
        Nothing -> continue

    withPathContent :: String -> Effect Unit -> Effect Unit
    withPathContent path' continue =
      withRouteContent (parseRoutePath path') continue

  cfg.mountSeaFooter
  mountCubeLogo
  cfg.gfxBootCheckNoCubeHosts
  inst.run
  applyThemeMode (themeModeToString storedTheme)
  patchRelativeDates
  everyMsInterval 60000 patchRelativeDates
  case initialRoute of
    SectionPost section slug
      | not (postHasBodyBlocks manifest section slug) ->
        ensurePostContent section slug do pure unit
    _ -> pure unit
  syncArticleChrome (Just initialRoute)
  _ <-
    setupRouteInputs
      appRootNode
      lunaRouteCodec
      Routing.PathRouting
      (\maybeRoute ->
        withRouteContent maybeRoute do
          inst.pushAndRun (SiteApp.RouteChanged maybeRoute)
          syncArticleChrome maybeRoute
          patchRelativeDates
      )
      (\path' ->
        withPathContent path' do
          let route = parseRoutePath path'
          inst.pushAndRun (SiteApp.RouteChanged route)
          syncArticleChrome route
          patchRelativeDates
      )
      (\id -> inst.pushAndRun (SiteApp.SetActiveToc id))
  setupScrollSpy "content-scroll" \maybeId ->
    case maybeId of
      Nothing -> pure unit
      Just id -> inst.pushAndRun (SiteApp.SetActiveToc id)
  cfg.setupTocHashSync \hashFrag -> inst.pushAndRun (SiteApp.SetActiveToc hashFrag)
  hash <- Location.hash loc
  when (String.length hash > 1) do
    let id = String.drop 1 hash
    inst.pushAndRun (SiteApp.SetActiveToc id)
    scrollToHashId id
