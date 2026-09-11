-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE RecursiveDo      #-}
-----------------------------------------------------------------------------
-- | The sea footer shader, ported from the source site's
-- @Platform.Browser.Sea@ + @Platform.Browser.Sea.ts@. The pure half lives in
-- 'Site.Sea'; this module owns the context, the resources, the animation
-- loop and the observers.
--
-- One mount owns one 'Site.Widgets.Browser.Mount' and scope. 'mount' is
-- called through the canvas's @onCreatedWith@ hook (which hydration fires),
-- and the owning slot makes it idempotent; releasing the scope releases the
-- context, which keeps repeated navigation under the browser's live-context
-- cap.
--
-- Like 'Site.Platform', the module is written against "Miso.DSL" and carries
-- no @foreign import javascript@, so it builds for the native test and
-- prerender targets; the effects are simply never run there.
module Site.Widgets.Sea
  ( mount
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (unless, void, when)
import           Control.Monad.Trans.Class (lift)
import           Control.Monad.Trans.Maybe (MaybeT (..))
import           Prelude hiding ((!!))
import           Data.IORef
  ( IORef
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
  , setField
  , (!)
  , (#)
  , (!!)
  )
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Platform (prefersReducedMotion)
import           Site.Sea
import           Site.Widgets.Gl
import qualified Site.Widgets.Browser as Browser
import qualified Site.FrameLoop as Frame
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
-- | Everything mounted for a live canvas. The scope and loop own cleanup;
-- the 'Live' value itself is only needed while registering callbacks.
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
  , liveScope            :: Browser.Scope
  , liveState            :: IORef SeaState
  , liveLayout           :: IORef RenderLayout
  , liveBounds           :: IORef (Double, Double)
  , liveIntersecting     :: IORef Bool
  , liveLoop             :: Frame.FrameLoop
  , livePrevious         :: IORef (Maybe SeaUniforms)
  }
-----------------------------------------------------------------------------
-- | False asks the owning mount slot to retry context acquisition.
mount :: Browser.Scope -> JSVal -> IO Bool
mount owner canvas = do
  markSeaState canvas "starting"
  context <- createWebGl2Context canvas
  case context of
    Nothing -> do
      markSeaState canvas "retrying"
      pure False
    Just gl -> do
      scope <- Browser.newScope
      Browser.own owner (Browser.disposeScope scope)
      Browser.own scope (releaseContext gl)
      built <- build scope canvas gl
      case built of
        Nothing -> do
          markSeaState canvas "failed"
          Browser.disposeScope scope
        Just _ -> markSeaState canvas "ready"
      pure True

-- | @data-sea@ is an attribute, not a property: the test harness and the
-- debugger read it off the canvas element.
markSeaState :: JSVal -> MisoString -> IO ()
markSeaState canvas state =
  void $ canvas # "setAttribute" $ ("data-sea" :: MisoString, state)

-- | Ask for another attempt after the frame in which the context cap was hit.
-- Chromium evicts contexts under pressure and frees them asynchronously, so
-- the window can be several seconds wide on a loaded machine.
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
build :: Browser.Scope -> JSVal -> JSVal -> IO (Maybe Live)
build scope canvas gl = runMaybeT $ do
  scene <- acquire scope (compileProgram gl seaFooterVertex seaFooterFragment "sea-water") (deleteProgram gl)
  composite <- acquire scope (compileProgram gl seaFooterVertex seaCompositeFragment "sea-composite") (deleteProgram gl)
  (texture, framebuffer) <- createTarget scope gl
  lift (createLive scope canvas gl scene composite texture framebuffer)
-----------------------------------------------------------------------------
-- | The offscreen color target the scene pass renders into.
createTarget :: Browser.Scope -> JSVal -> MaybeT IO (JSVal, JSVal)
createTarget scope gl = do
  texture <- acquire scope (optionalObject (gl # "createTexture" $ ())) (\value -> void $ gl # "deleteTexture" $ [value])
  framebuffer <- acquire scope (optionalObject (gl # "createFramebuffer" $ ())) (\value -> void $ gl # "deleteFramebuffer" $ [value])
  MaybeT $ do
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
createLive :: Browser.Scope -> JSVal -> JSVal -> GlProgram -> GlProgram -> JSVal -> JSVal -> IO Live
createLive scope canvas gl scene composite texture framebuffer = mdo
  locationTime <- uniformLocation gl scene "t"
  locationResolution <- uniformLocation gl scene "r"
  locationCubeOffset <- uniformLocation gl scene "cubeOff"
  locationCubeVelocity <- uniformLocation gl scene "cubeVel"
  locationDark <- uniformLocation gl scene "uiDark"
  locationIntro <- uniformLocation gl scene "seaIntro"
  locationLabHover <- uniformLocation gl scene "labHover"
  overlayOutputSize <- uniformLocation gl composite "outputSize"
  overlayDitherPixelSize <- uniformLocation gl composite "ditherPx"
  cloudQ <- uniformLocation gl scene "cloudQ"
  seaColorPass <- uniformLocation gl scene "seaColorPass"
  seaTexture <- uniformLocation gl composite "seaTexture"
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
  intersecting <- newIORef False
  loop <- Browser.frameLoop scope reduced (drawFrame live)
  previous <- newIORef Nothing
  darkRef <- newIORef dark
  hoverRef <- newIORef hover
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
        , liveScope = scope
        , liveState = state
        , liveLayout = layout
        , liveBounds = bounds
        , liveIntersecting = intersecting
        , liveLoop = loop
        , livePrevious = previous
        }
  applyLayout live
  registerPointer live
  registerResize live
  registerTheme live
  registerHover live
  registerIntersection live
  pure live
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
drawFrame :: Live -> Double -> IO ()
drawFrame live timestamp = do
  state <- readIORef (liveState live)
  layout <- readIORef (liveLayout live)
  hover <- readIORef (liveHoverTarget live)
  dark <- readIORef (liveDark live)
  let input = SeaInput
        { inputTimestamp = timestamp
        , inputStartedAt = liveStartedAt live
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
startLoop = Frame.invalidate . liveLoop
-----------------------------------------------------------------------------
addListener :: Live -> JSVal -> MisoString -> Bool -> (JSVal -> IO ()) -> IO ()
addListener live = Browser.listen (liveScope live)
-----------------------------------------------------------------------------
registerPointer :: Live -> IO ()
registerPointer live = do
  let canvas = liveCanvas live
  addListener live canvas "pointerdown" True $ \event -> do
    Browser.capturePointer canvas event
    handlePointer live PointerDown event
  addListener live canvas "pointermove" True (handlePointer live PointerMove)
  addListener live canvas "pointerup" True (handlePointer live PointerUp)
  addListener live canvas "pointercancel" True (handlePointer live PointerUp)
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
  options <- create
  void $ Browser.observe (liveScope live) "ResizeObserver" (Just (liveCanvas live)) options (\_ -> applyLayout live)
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
  let parent = liveParent live
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
  void $ Browser.observe (liveScope live) "MutationObserver" (Just target) options handler
-----------------------------------------------------------------------------
-- | The source gates the loop on both intersection (with a 120px margin) and
-- tab visibility. Window resizes are handled by 'registerResize' rather than
-- a @ResizeObserver@; the canvas spans the layout, so the two agree.
registerIntersection :: Live -> IO ()
registerIntersection live = do
  options <- create
  setField options "rootMargin" ("120px" :: MisoString)
  void $ Browser.observe (liveScope live) "IntersectionObserver" (Just (liveCanvas live)) options $ \entries -> do
    first <- entries !! 0
    intersecting <- fromJSValUnchecked =<< first ! "isIntersecting"
    writeIORef (liveIntersecting live) intersecting
    emitVisibility live
  document <- jsg "document"
  addListener live document "visibilitychange" False (\_ -> emitVisibility live)
-----------------------------------------------------------------------------
emitVisibility :: Live -> IO ()
emitVisibility live = do
  intersecting <- readIORef (liveIntersecting live)
  document <- jsg "document"
  visibility <- fromJSValUnchecked =<< document ! "visibilityState"
  let visible = intersecting && visibility == ("visible" :: MisoString)
  Frame.setVisible (liveLoop live) visible
