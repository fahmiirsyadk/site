-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
-----------------------------------------------------------------------------
-- | The sea footer shader, ported from the source site's
-- @Platform.Browser.Sea@ + @Platform.Browser.Sea.ts@. The pure half lives in
-- 'Site.Sea'; this module owns the context, the resources, the animation
-- loop and the observers.
--
-- One instance exists at a time. 'attach' is idempotent and is called from
-- the canvas's @onCreated@ hook (which hydration fires), so a prerendered
-- page boots the shader without any client-side routing. 'dispose' runs from
-- @onBeforeDestroyed@ and releases the context, which is what keeps repeated
-- navigation under the browser's live-context cap.
--
-- Like 'Site.Platform', the module is written against "Miso.DSL" and carries
-- no @foreign import javascript@, so it builds for the native test and
-- prerender targets; the effects are simply never run there.
module Site.Widgets.Sea
  ( attach
  , dispose
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (forM_, unless, void, when)
import           Control.Exception (finally)
import           Data.Maybe (isJust)
import           Prelude hiding ((!!))
import           Data.IORef
  ( IORef
  , modifyIORef'
  , newIORef
  , readIORef
  , writeIORef
  )
import           Miso.DSL
  ( JSVal
  , create
  , fromJSVal
  , fromJSValUnchecked
  , jsg
  , jsNull
  , new
  , setField
  , syncCallback1
  , (!)
  , (#)
  , (!!)
  )
import           Miso.String (MisoString)
import           System.IO.Unsafe (unsafePerformIO)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Platform (prefersReducedMotion)
import           Site.Sea
import           Site.Widgets.Gl
import           Site.Widgets.Shaders
  ( seaCompositeFragment
  , seaFooterFragment
  , seaFooterVertex
  )
-----------------------------------------------------------------------------
-- | Uniform locations in the scene program.
data Locations = Locations
  { locationTime         :: JSVal
  , locationResolution   :: JSVal
  , locationCubeOffset   :: JSVal
  , locationCubeVelocity :: JSVal
  , locationDark         :: JSVal
  , locationIntro        :: JSVal
  , locationLabHover     :: JSVal
  }
-----------------------------------------------------------------------------
-- | Uniform locations in the composite program.
data Overlay = Overlay
  { overlayOutputSize      :: JSVal
  , overlayDitherPixelSize :: JSVal
  }
-----------------------------------------------------------------------------
-- | One registered event listener, kept so 'dispose' can remove it.
data Listener = Listener
  { listenerTarget   :: JSVal
  , listenerType     :: MisoString
  , listenerCallback :: JSVal
  , listenerCapture  :: Bool
  }
-----------------------------------------------------------------------------
-- | Everything mounted for a live canvas.
data Live = Live
  { liveCanvas           :: JSVal
  , liveGl               :: JSVal
  , liveScene            :: GlProgram
  , liveComposite        :: GlProgram
  , liveFramebuffer      :: JSVal
  , liveTexture          :: JSVal
  , liveLocations        :: Locations
  , liveOverlay          :: Overlay
  , liveParent           :: JSVal
  , liveStartedAt        :: Double
  , liveReducedMotion    :: Bool
  , liveDark             :: IORef Bool
  , liveHoverTarget      :: IORef Double
  , liveObservers        :: IORef [JSVal]
  , liveState            :: IORef SeaState
  , liveLayout           :: IORef RenderLayout
  , liveBounds           :: IORef (Double, Double)
  , liveVisible          :: IORef Bool
  , liveIntersecting     :: IORef Bool
  , liveRunning          :: IORef Bool
  , liveRafCallback      :: IORef JSVal
  , liveRafHandle        :: IORef (Maybe Int)
  , livePrevious         :: IORef (Maybe SeaUniforms)
  , liveListeners        :: IORef [Listener]
  , liveObserver         :: IORef JSVal
  }
-----------------------------------------------------------------------------
-- The one live mount. Kept in a top-level ref because the canvas is unique
-- and the effect is imperative on both sides of the boundary.
liveRef :: IORef (Maybe Live)
liveRef = unsafePerformIO (newIORef Nothing)
{-# NOINLINE liveRef #-}
-----------------------------------------------------------------------------
-- 'SeaMounted' and the component mount action are both intentional entry
-- points, but they can arrive before the first WebGL build has published
-- 'liveRef'. Serialize that short window so both callers do not compile two
-- programs against the same canvas and leave uniforms associated with the
-- other program.
mountingRef :: IORef Bool
mountingRef = unsafePerformIO (newIORef False)
{-# NOINLINE mountingRef #-}
-----------------------------------------------------------------------------
-- | How many times a missing context has been retried. Chromium evicts the
-- oldest WebGL context when a page holds too many; a fresh canvas can
-- transiently fail to get one and succeed a moment later.
retryRef :: IORef Int
retryRef = unsafePerformIO (newIORef 0)
{-# NOINLINE retryRef #-}
-----------------------------------------------------------------------------
-- | Mount the shader if the canvas is in the document and nothing is live.
-- Safe to call from both hydration and a client-side mount.
attach :: IO ()
attach = do
  current <- readIORef liveRef
  mounting <- readIORef mountingRef
  case (current, mounting) of
    (Just _, _)  -> pure ()
    (Nothing, True) -> pure ()
    (Nothing, False) -> do
      writeIORef mountingRef True
      (do
        document <- jsg "document"
        canvas <- document # "querySelector" $ ("#" <> Config.seaCanvasId)
        absent <- isAbsent canvas
        unless absent (mount canvas)
       ) `finally` writeIORef mountingRef False
-----------------------------------------------------------------------------
-- | Tear down the live mount, if any.
dispose :: IO ()
dispose = do
  current <- readIORef liveRef
  case current of
    Nothing   -> pure ()
    Just live -> do
      stopLoop live
      listeners <- readIORef (liveListeners live)
      forM_ (reverse listeners) $ \listener ->
        void $ listenerTarget listener # "removeEventListener" $
          ( listenerType listener
          , listenerCallback listener
          , listenerCapture listener
          )
      observer <- readIORef (liveObserver live)
      absent <- isAbsent observer
      unless absent $ void $ observer # "disconnect" $ ()
      observers <- readIORef (liveObservers live)
      forM_ observers $ \mutationObserver ->
        void $ mutationObserver # "disconnect" $ ()
      let gl = liveGl live
      void $ gl # "deleteFramebuffer" $ [liveFramebuffer live]
      void $ gl # "deleteTexture" $ [liveTexture live]
      deleteProgram gl (liveScene live)
      deleteProgram gl (liveComposite live)
      releaseContext gl
      writeIORef liveRef Nothing
-----------------------------------------------------------------------------
mount :: JSVal -> IO ()
mount canvas = do
  markSeaState canvas "starting"
  context <- createWebGl2Context canvas
  case context of
    Nothing -> do
      markSeaState canvas "retrying"
      retryMount
    Just gl -> do
      built <- build canvas gl
      case built of
        Nothing -> do
          markSeaState canvas "failed"
          releaseContext gl
        Just live -> do
          writeIORef retryRef 0
          markSeaState canvas "ready"
          writeIORef liveRef (Just live)

-- | @data-sea@ is an attribute, not a property: the test harness and the
-- debugger read it off the canvas element.
markSeaState :: JSVal -> MisoString -> IO ()
markSeaState canvas state =
  void $ canvas # "setAttribute" $ ("data-sea" :: MisoString, state)

-- | Ask for another attempt after the frame in which the context cap was hit.
-- Chromium evicts contexts under pressure and frees them asynchronously, so
-- the window can be several seconds wide on a loaded machine.
retryMount :: IO ()
retryMount = mountWithRetry retryRef (isJust <$> readIORef liveRef) attach
-----------------------------------------------------------------------------
createWebGl2Context :: JSVal -> IO (Maybe JSVal)
createWebGl2Context canvas = do
  options <- create
  setField options "alpha" True
  setField options "premultipliedAlpha" False
  setField options "antialias" False
  setField options "depth" False
  setField options "stencil" False
  context <- canvas # "getContext" $ ("webgl2" :: MisoString, options)
  absent <- isAbsent context
  pure (if absent then Nothing else Just context)
-----------------------------------------------------------------------------
build :: JSVal -> JSVal -> IO (Maybe Live)
build canvas gl =
  compileProgram gl seaFooterVertex seaFooterFragment "sea-water" >>>= \scene ->
  compileProgram gl seaFooterVertex seaCompositeFragment "sea-composite" >>>= \composite ->
  createTarget gl >>>= \(texture, framebuffer) ->
  createLive canvas gl scene composite texture framebuffer
-----------------------------------------------------------------------------
-- | The offscreen color target the scene pass renders into.
createTarget :: JSVal -> IO (Maybe (JSVal, JSVal))
createTarget gl = do
  texture <- gl # "createTexture" $ ()
  framebuffer <- gl # "createFramebuffer" $ ()
  textureAbsent <- isAbsent texture
  framebufferAbsent <- isAbsent framebuffer
  if textureAbsent || framebufferAbsent
    then pure Nothing
    else do
      void $ gl # "activeTexture" $ [glTexture0]
      void $ gl # "bindTexture" $ (glTexture2D, texture)
      void $ gl # "texParameteri" $ (glTexture2D, glTextureMinFilter, glLinear)
      void $ gl # "texParameteri" $ (glTexture2D, glTextureMagFilter, glLinear)
      void $ gl # "texParameteri" $ (glTexture2D, glTextureWrapS, glClampToEdge)
      void $ gl # "texParameteri" $ (glTexture2D, glTextureWrapT, glClampToEdge)
      texImage2DNull gl glTexture2D 0 glRgba8 1 1 0 glRgba glUnsignedByte
      void $ gl # "bindFramebuffer" $ (glFramebuffer, framebuffer)
      void $ gl # "framebufferTexture2D" $
        (glFramebuffer, glColorAttachment0, glTexture2D, texture, 0 :: Int)
      statusValue <- gl # "checkFramebufferStatus" $ [glFramebuffer]
      status <- fromJSValUnchecked statusValue
      void $ gl # "bindFramebuffer" $ (glFramebuffer, jsNull)
      pure (if status == glFramebufferComplete then Just (texture, framebuffer) else Nothing)
-----------------------------------------------------------------------------
createLive :: JSVal -> JSVal -> GlProgram -> GlProgram -> JSVal -> JSVal -> IO (Maybe Live)
createLive canvas gl scene composite texture framebuffer = do
  locationTime <- getUniform gl (glProgram scene) "t"
  locationResolution <- getUniform gl (glProgram scene) "r"
  locationCubeOffset <- getUniform gl (glProgram scene) "cubeOff"
  locationCubeVelocity <- getUniform gl (glProgram scene) "cubeVel"
  locationDark <- getUniform gl (glProgram scene) "uiDark"
  locationIntro <- getUniform gl (glProgram scene) "seaIntro"
  locationLabHover <- getUniform gl (glProgram scene) "labHover"
  overlayOutputSize <- getUniform gl (glProgram composite) "outputSize"
  overlayDitherPixelSize <- getUniform gl (glProgram composite) "ditherPx"
  cloudQ <- getUniform gl (glProgram scene) "cloudQ"
  seaColorPass <- getUniform gl (glProgram scene) "seaColorPass"
  seaTexture <- getUniform gl (glProgram composite) "seaTexture"
  void $ gl # "useProgram" $ [glProgram scene]
  void $ gl # "uniform1f" $ (cloudQ, 0.6 :: Double)
  void $ gl # "uniform1f" $ (seaColorPass, 1.0 :: Double)
  void $ gl # "useProgram" $ [glProgram composite]
  void $ gl # "uniform1i" $ (seaTexture, 0 :: Int)
  parent <- canvas ! "parentElement"
  startedAt <- performanceNow
  reduced <- prefersReducedMotion
  hover <- readLabHover parent
  dark <- isDarkTheme
  state <- newIORef (initialSeaState startedAt hover)
  layout <- newIORef (renderLayoutFor 1.0 1.0 1.0)
  bounds <- newIORef (1.0, 1.0)
  visible <- newIORef False
  intersecting <- newIORef False
  running <- newIORef False
  rafCallback <- newIORef jsNull
  rafHandle <- newIORef Nothing
  previous <- newIORef Nothing
  listeners <- newIORef []
  observer <- newIORef jsNull
  darkRef <- newIORef dark
  hoverRef <- newIORef hover
  observers <- newIORef []
  let live = Live
        { liveCanvas = canvas
        , liveGl = gl
        , liveScene = scene
        , liveComposite = composite
        , liveFramebuffer = framebuffer
        , liveTexture = texture
        , liveLocations = Locations
            { locationTime = locationTime
            , locationResolution = locationResolution
            , locationCubeOffset = locationCubeOffset
            , locationCubeVelocity = locationCubeVelocity
            , locationDark = locationDark
            , locationIntro = locationIntro
            , locationLabHover = locationLabHover
            }
        , liveOverlay = Overlay
            { overlayOutputSize = overlayOutputSize
            , overlayDitherPixelSize = overlayDitherPixelSize
            }
        , liveParent = parent
        , liveStartedAt = startedAt
        , liveReducedMotion = reduced
        , liveDark = darkRef
        , liveHoverTarget = hoverRef
        , liveObservers = observers
        , liveState = state
        , liveLayout = layout
        , liveBounds = bounds
        , liveVisible = visible
        , liveIntersecting = intersecting
        , liveRunning = running
        , liveRafCallback = rafCallback
        , liveRafHandle = rafHandle
        , livePrevious = previous
        , liveListeners = listeners
        , liveObserver = observer
        }
  callback <- syncCallback1 $ \timestamp -> tick live timestamp
  writeIORef rafCallback callback
  applyLayout live
  registerPointer live
  registerResize live
  registerTheme live
  registerHover live
  registerIntersection live
  pure (Just live)
-----------------------------------------------------------------------------
getUniform :: JSVal -> JSVal -> MisoString -> IO JSVal
getUniform gl program name = gl # "getUniformLocation" $ (program, name)
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
readLabHover :: JSVal -> IO Double
readLabHover parent = do
  absent <- isAbsent parent
  if absent
    then pure 0.0
    else do
      value <- parent # "getAttribute" $ ("data-" <> Config.labInteractionKey)
      text <- fromJSVal value :: IO (Maybe MisoString)
      pure (if text == Just Config.labInteractionHovered then 1.0 else 0.0)
-----------------------------------------------------------------------------
isDarkTheme :: IO Bool
isDarkTheme = do
  document <- jsg "document"
  element <- document ! "documentElement"
  classes <- element ! "classList"
  contained <- classes # "contains" $ Config.darkClassName
  fromJSValUnchecked contained
-----------------------------------------------------------------------------
-- | Re-measure the canvas, resize both render targets, and tell the
-- composite pass where the output lives.
applyLayout :: Live -> IO ()
applyLayout live = do
  let canvas = liveCanvas live
      gl = liveGl live
  rect <- canvas # "getBoundingClientRect" $ ()
  width <- fromJSValUnchecked =<< rect ! "width"
  height <- fromJSValUnchecked =<< rect ! "height"
  -- Hydration can run before the stylesheet gives the canvas its height.
  -- Leave the defaults alone and let the ResizeObserver call back with a
  -- real box instead of baking in a one-pixel-high backing store.
  when (width >= 1.0 && height >= 1.0) $ do
    window <- jsg "window"
    ratio <- fromJSValUnchecked =<< window ! "devicePixelRatio"
    let layout = renderLayoutFor width height ratio
    writeIORef (liveBounds live) (width, height)
    writeIORef (liveLayout live) layout
    writeIORef (livePrevious live) Nothing
    setField canvas "width" (canvasWidth layout)
    setField canvas "height" (canvasHeight layout)
    void $ gl # "activeTexture" $ [glTexture0]
    void $ gl # "bindTexture" $ (glTexture2D, liveTexture live)
    texImage2DNull gl glTexture2D 0 glRgba8
      (sceneWidth layout) (sceneHeight layout) 0 glRgba glUnsignedByte
    void $ gl # "useProgram" $ [glProgram (liveComposite live)]
    void $ gl # "uniform2f" $
      ( overlayOutputSize (liveOverlay live)
      , fromIntegral (canvasWidth layout) :: Double
      , fromIntegral (canvasHeight layout) :: Double
      )
    void $ gl # "uniform1f" $
      (overlayDitherPixelSize (liveOverlay live), pixelRatio layout)
    startLoop live
-----------------------------------------------------------------------------
tick :: Live -> JSVal -> IO ()
tick live rawTimestamp = do
  running <- readIORef (liveRunning live)
  when running $ do
    timestamp <- fromJSValUnchecked rawTimestamp
    drawFrame live timestamp
    scheduleFrame live
-----------------------------------------------------------------------------
scheduleFrame :: Live -> IO ()
scheduleFrame live = do
  callback <- readIORef (liveRafCallback live)
  window <- jsg "window"
  handle <- window # "requestAnimationFrame" $ [callback]
  handleId <- fromJSValUnchecked handle
  writeIORef (liveRafHandle live) (Just handleId)
-----------------------------------------------------------------------------
drawFrame :: Live -> Double -> IO ()
drawFrame live timestamp = do
  state <- readIORef (liveState live)
  layout <- readIORef (liveLayout live)
  hover <- readIORef (liveHoverTarget live)
  dark <- readIORef (liveDark live)
  let input = SeaInput
        { inputTimestamp = timestamp
        , inputStartedAt = liveStartedAt live
        , inputDragging = stateDragging state
        , inputLabHoverTarget = hover
        , inputCanvasWidth = sceneWidth layout
        , inputCanvasHeight = sceneHeight layout
        , inputDark = dark
        , inputReducedMotion = liveReducedMotion live
        }
      (stepped, uniforms) = seaFrame input state
  writeIORef (liveState live) stepped
  previous <- readIORef (livePrevious live)
  when (previous /= Just uniforms) $ do
    drawUniforms live layout uniforms
    writeIORef (livePrevious live) (Just uniforms)
-----------------------------------------------------------------------------
drawUniforms :: Live -> RenderLayout -> SeaUniforms -> IO ()
drawUniforms live layout uniforms = do
  let gl = liveGl live
      scene = liveScene live
      composite = liveComposite live
      Locations {..} = liveLocations live
  void $ gl # "bindFramebuffer" $ (glFramebuffer, liveFramebuffer live)
  void $ gl # "viewport" $
    (0 :: Int, 0 :: Int, sceneWidth layout, sceneHeight layout)
  void $ gl # "useProgram" $ [glProgram scene]
  void $ gl # "uniform1f" $ (locationTime, time uniforms)
  void $ gl # "uniform2f" $ (locationResolution, resolutionX uniforms, resolutionY uniforms)
  void $ gl # "uniform2f" $ (locationCubeOffset, cubeX uniforms, cubeY uniforms)
  void $ gl # "uniform2f" $ (locationCubeVelocity, velocityX uniforms, velocityY uniforms)
  void $ gl # "uniform1f" $ (locationDark, uiDark uniforms)
  void $ gl # "uniform1f" $ (locationIntro, intro uniforms)
  void $ gl # "uniform1f" $ (locationLabHover, labHover uniforms)
  void $ gl # "drawArrays" $ (glTriangles, 0 :: Int, 3 :: Int)
  void $ gl # "bindFramebuffer" $ (glFramebuffer, jsNull)
  void $ gl # "viewport" $
    (0 :: Int, 0 :: Int, canvasWidth layout, canvasHeight layout)
  void $ gl # "useProgram" $ [glProgram composite]
  void $ gl # "activeTexture" $ [glTexture0]
  void $ gl # "bindTexture" $ (glTexture2D, liveTexture live)
  void $ gl # "drawArrays" $ (glTriangles, 0 :: Int, 3 :: Int)
-----------------------------------------------------------------------------
-- | Request a frame if the canvas is on screen and none is scheduled.
startLoop :: Live -> IO ()
startLoop live = do
  running <- readIORef (liveRunning live)
  visible <- readIORef (liveVisible live)
  when (not running && visible) $ do
    writeIORef (liveRunning live) True
    scheduleFrame live
-----------------------------------------------------------------------------
stopLoop :: Live -> IO ()
stopLoop live = do
  writeIORef (liveRunning live) False
  handle <- readIORef (liveRafHandle live)
  forM_ handle $ \handleId -> do
    window <- jsg "window"
    void $ window # "cancelAnimationFrame" $ [handleId]
  writeIORef (liveRafHandle live) Nothing
-----------------------------------------------------------------------------
addListener :: Live -> JSVal -> MisoString -> Bool -> (JSVal -> IO ()) -> IO ()
addListener live target kind capture handler = do
  callback <- syncCallback1 handler
  void $ target # "addEventListener" $ (kind, callback, capture)
  modifyIORef' (liveListeners live) (Listener target kind callback capture :)
-----------------------------------------------------------------------------
registerPointer :: Live -> IO ()
registerPointer live = do
  let canvas = liveCanvas live
  addListener live canvas "pointerdown" True $ \event -> do
    capturePointer canvas event
    handlePointer live PointerDown event
  addListener live canvas "pointermove" True (handlePointer live PointerMove)
  addListener live canvas "pointerup" True (handlePointer live PointerUp)
  addListener live canvas "pointercancel" True (handlePointer live PointerUp)
-----------------------------------------------------------------------------
capturePointer :: JSVal -> JSVal -> IO ()
capturePointer canvas event = do
  pointerId <- event ! "pointerId"
  void $ canvas # "setPointerCapture" $ [pointerId]
-----------------------------------------------------------------------------
handlePointer :: Live -> SeaPointerKind -> JSVal -> IO ()
handlePointer live kind event = do
  void $ event # "preventDefault" $ ()
  (width, height) <- readIORef (liveBounds live)
  x <- fromJSValUnchecked =<< event ! "clientX"
  y <- fromJSValUnchecked =<< event ! "clientY"
  state <- readIORef (liveState live)
  writeIORef (liveState live)
    (seaPointer (SeaPointerEvent kind x y width height) state)
  startLoop live
-----------------------------------------------------------------------------
-- | The source observes the element, not the window: the canvas keeps a
-- clamped height across breakpoints and can be laid out lazily, so a window
-- resize alone would miss the first real box (and any container change).
registerResize :: Live -> IO ()
registerResize live = do
  callback <- syncCallback1 $ \_ -> applyLayout live
  observerClass <- jsg "ResizeObserver"
  observer <- new observerClass callback
  void $ observer # "observe" $ [liveCanvas live]
  modifyIORef' (liveObservers live) (observer :)
-----------------------------------------------------------------------------
-- | Theme and lab-hover changes arrive through @MutationObserver@, the same
-- way the source's @observeTheme@ and @observeDataAttribute@ do. Reading the
-- DOM every frame would put two extra JavaScript crossings in the hot path
-- for values that change a handful of times per visit.
registerTheme :: Live -> IO ()
registerTheme live = do
  document <- jsg "document"
  element <- document ! "documentElement"
  addAttributeObserver live element $ \_ -> do
    value <- isDarkTheme
    writeIORef (liveDark live) value
    startLoop live
-----------------------------------------------------------------------------
registerHover :: Live -> IO ()
registerHover live = do
  parent <- pure (liveParent live)
  absent <- isAbsent parent
  unless absent $
    addAttributeObserver live parent $ \_ -> do
      value <- readLabHover parent
      writeIORef (liveHoverTarget live) value
      startLoop live
-----------------------------------------------------------------------------
addAttributeObserver :: Live -> JSVal -> (JSVal -> IO ()) -> IO ()
addAttributeObserver live target handler = do
  options <- create
  setField options "attributes" True
  callback <- syncCallback1 handler
  observerClass <- jsg "MutationObserver"
  observer <- new observerClass callback
  void $ observer # "observe" $ (target, options)
  modifyIORef' (liveObservers live) (observer :)
-----------------------------------------------------------------------------
-- | The source gates the loop on both intersection (with a 120px margin) and
-- tab visibility. Window resizes are handled by 'registerResize' rather than
-- a @ResizeObserver@; the canvas spans the layout, so the two agree.
registerIntersection :: Live -> IO ()
registerIntersection live = do
  options <- create
  setField options "rootMargin" ("120px" :: MisoString)
  observerClass <- jsg "IntersectionObserver"
  callback <- syncCallback1 $ \entries -> do
    first <- entries !! 0
    intersecting <- fromJSValUnchecked =<< first ! "isIntersecting"
    writeIORef (liveIntersecting live) intersecting
    emitVisibility live
  observer <- new observerClass (callback, options)
  void $ observer # "observe" $ [liveCanvas live]
  writeIORef (liveObserver live) observer
  document <- jsg "document"
  addListener live document "visibilitychange" False (\_ -> emitVisibility live)
-----------------------------------------------------------------------------
emitVisibility :: Live -> IO ()
emitVisibility live = do
  intersecting <- readIORef (liveIntersecting live)
  document <- jsg "document"
  visibility <- fromJSValUnchecked =<< document ! "visibilityState"
  let visible = intersecting && visibility == ("visible" :: MisoString)
  writeIORef (liveVisible live) visible
  if visible then startLoop live else stopLoop live
