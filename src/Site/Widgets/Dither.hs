-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
-----------------------------------------------------------------------------
-- | The dithered image widget, ported from the source's @DitheredImage.purs@
-- + @DitheredImage.ts@. WebGL1 draws the source image through an ordered
-- dither in the theme's ink color.
--
-- Unlike the sea and the hollow mark there can be many instances at once --
-- a post cover and every inline image in its body -- so this module keeps a
-- registry keyed by root element. 'attach' observes @document.body@ for
-- subtree child-list changes: Miso patches page content in place, so the
-- observer is what mounts roots on navigation and disposes them when their
-- page leaves the DOM. Roots carry a @data-dither-initialized@ marker so a
-- still-connected root is never mounted twice, and a root disposed while it
-- was removed is mounted again if it comes back.
--
-- Like the other widget modules this is written against "Miso.DSL" and
-- carries no @foreign import javascript@, so it compiles for the native test
-- and prerender targets, where the effects are simply never run.
module Site.Widgets.Dither
  ( attach
  , dispose
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (filterM, forM_, unless, void, when)
import           Data.IORef
  ( IORef
  , modifyIORef'
  , newIORef
  , readIORef
  , writeIORef
  )
import           Data.Maybe (listToMaybe)
import           Prelude hiding ((!!))
import           Miso.DSL
  ( JSVal
  , create
  , fromJSValUnchecked
  , jsg
  , jsNull
  , new
  , setField
  , syncCallback1
  , toJSVal
  , (!)
  , (#)
  , (!!)
  )
import           Miso.String (MisoString, ms)
import           System.IO.Unsafe (unsafePerformIO)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Dither
import           Site.Platform (prefersReducedMotion)
import           Site.Widgets.Gl
import           Site.Widgets.Shaders
  ( ditheredImageFragment
  , ditheredImageVertex
  )
-----------------------------------------------------------------------------
-- | One registered listener, kept so disposal can remove it.
data Listener = Listener
  { listenerTarget   :: JSVal
  , listenerType     :: MisoString
  , listenerCallback :: JSVal
  , listenerCapture  :: Bool
  }
-----------------------------------------------------------------------------
-- | The per-instance GL objects and uniform locations.
data Resources = Resources
  { resGl             :: JSVal
  , resProgram        :: GlProgram
  , resImageTexture   :: JSVal
  , resBayerTexture   :: JSVal
  , resPositionBuffer :: JSVal
  , resTextureBuffer  :: JSVal
  , resPositionAt     :: Int
  , resTexCoordAt     :: Int
  , resResolution     :: JSVal
  , resTime           :: JSVal
  , resInk            :: JSVal
  }
-----------------------------------------------------------------------------
data DitherState = DitherState
  { dsLastFrame :: Double
  , dsDisposed  :: Bool
  , dsLost      :: Bool
  , dsUploaded  :: Bool
  , dsVisible   :: Bool
  , dsReady     :: Bool
  }
-----------------------------------------------------------------------------
-- | One mounted root: the element and everything acquired for it. 'Nothing'
-- means the root was marked initialized but failed to prepare -- a missing
-- canvas, no WebGL, a shader error -- and is showing its fallback image.
data Entry = Entry
  { entryRoot :: JSVal
  , entryLive :: Maybe Live
  }
-----------------------------------------------------------------------------
data Live = Live
  { liveRoot         :: JSVal
  , liveImage        :: JSVal
  , liveCanvas       :: JSVal
  , liveResources    :: IORef (Maybe Resources)
  , liveReduceMotion :: Bool
  , liveState        :: IORef DitherState
  , liveInk          :: IORef Rgb
  , liveRafCallback  :: IORef JSVal
  , liveRafHandle    :: IORef (Maybe Int)
  , liveListeners    :: IORef [Listener]
  , liveObservers    :: IORef [JSVal]
  }
-----------------------------------------------------------------------------
-- The live roots and the one body observer. Top-level refs because the
-- effects are imperative on both sides of the boundary.
registryRef :: IORef [Entry]
registryRef = unsafePerformIO (newIORef [])
{-# NOINLINE registryRef #-}
-----------------------------------------------------------------------------
observerRef :: IORef (Maybe JSVal)
observerRef = unsafePerformIO (newIORef Nothing)
{-# NOINLINE observerRef #-}

-- A root below the fold is kept as an ordinary image until it is close to
-- the viewport. This avoids compiling a shader and allocating a WebGL context
-- for every image in a long post during startup.
--
-- The observer can only report what is inside the scroll container: the
-- container clips its content, so neither the viewport root nor the container
-- root can use a margin to see further down. 'mountNearby' is what mounts a
-- root one screen before it could be seen.
visibilityObserverRef :: IORef (Maybe JSVal)
visibilityObserverRef = unsafePerformIO (newIORef Nothing)
{-# NOINLINE visibilityObserverRef #-}

-- The capture-phase scroll listener that feeds 'mountNearby'.
scrollListenerRef :: IORef (Maybe (JSVal, JSVal))
scrollListenerRef = unsafePerformIO (newIORef Nothing)
{-# NOINLINE scrollListenerRef #-}

-- IntersectionObserver retains every target passed to 'observe'. A target is
-- pending until its callback promotes it into 'registryRef'; keep that set
-- explicitly so a route swap can unobserve roots that never became live.
pendingRef :: IORef [JSVal]
pendingRef = unsafePerformIO (newIORef [])
{-# NOINLINE pendingRef #-}
-----------------------------------------------------------------------------
-- | Discover uninitialized roots and set up the body observer that keeps the
-- registry in step with client-side navigation. Roots near the viewport are
-- mounted immediately; below-fold roots remain pending. Idempotent.
attach :: IO ()
attach = do
  existing <- readIORef observerRef
  case existing of
    Just _  -> syncRegistry
    Nothing -> do
      document <- jsg "document"
      body <- document ! "body"
      callback <- syncCallback1 $ \_ -> syncRegistry
      options <- create
      setField options "childList" True
      setField options "subtree" True
      observerClass <- jsg "MutationObserver"
      observer <- new observerClass callback
      void $ observer # "observe" $ (body, options)
      writeIORef observerRef (Just observer)
      ensureVisibilityObserver
      registerScrollMount
      syncRegistry
-----------------------------------------------------------------------------
-- | Release every root and stop observing. A remount starts clean.
dispose :: IO ()
dispose = do
  observer <- readIORef observerRef
  forM_ observer $ \value -> void $ value # "disconnect" $ ()
  writeIORef observerRef Nothing
  listener <- readIORef scrollListenerRef
  forM_ listener $ \(target, callback) ->
    void $ target # "removeEventListener" $
      ("scroll" :: MisoString, callback, True)
  writeIORef scrollListenerRef Nothing
  visibilityObserver <- readIORef visibilityObserverRef
  pending <- readIORef pendingRef
  writeIORef pendingRef []
  forM_ visibilityObserver $ \value -> do
    forM_ pending $ \root -> void $ value # "unobserve" $ [root]
    void $ value # "disconnect" $ ()
  writeIORef visibilityObserverRef Nothing
  entries <- readIORef registryRef
  writeIORef registryRef []
  forM_ entries disposeEntry
-----------------------------------------------------------------------------
-- | Dispose roots that left the DOM, then mount roots that appeared. The
-- removals run first so a content swap releases its GL contexts before the
-- incoming images acquire theirs.
syncRegistry :: IO ()
syncRegistry = do
  ensureVisibilityObserver
  entries <- readIORef registryRef
  current <- mapM (isDitherRoot . entryRoot) entries
  let kept = [ entry | (entry, True) <- zip entries current ]
      departed = [ entry | (entry, False) <- zip entries current ]
  writeIORef registryRef kept
  forM_ departed disposeEntry
  visibilityObserver <- readIORef visibilityObserverRef
  forM_ visibilityObserver $ \observer -> do
    forM_ departed $ \entry -> unobservePending observer (entryRoot entry)
    reconcilePending observer
  document <- jsg "document"
  roots <- document # "querySelectorAll" $ Config.ditheredImageSelector
  count <- int roots "length"
  case visibilityObserver of
    Just observer ->
      forM_ [0 .. count - 1] $ \index -> do
        root <- roots !! index
        initialized <- readInitialized root
        if initialized
          then do
            -- Keep live roots observed. A recreated observer has to learn
            -- about roots that were already mounted.
            observeRoot observer root
            forgetPending root
          else trackPending observer root
    Nothing ->
      -- Older browsers without IntersectionObserver still get the original
      -- eager behavior; keeping the source image visible makes this safe.
      forM_ [0 .. count - 1] $ \index -> do
        root <- roots !! index
        initialized <- readInitialized root
        unless initialized (mountOne root)
  mountNearby

-- | Capture-phase scroll listener: scroll does not bubble, but a listener on
-- the document still sees the container's events on the way down. Mounting
-- itself runs from the scroll callback so a root is ready a screen before it
-- can be seen.
registerScrollMount :: IO ()
registerScrollMount = do
  existing <- readIORef scrollListenerRef
  case existing of
    Just _  -> pure ()
    Nothing -> do
      document <- jsg "document"
      callback <- syncCallback1 $ \_ -> mountNearby
      void $ document # "addEventListener" $ ("scroll" :: MisoString, callback, True)
      writeIORef scrollListenerRef (Just (document, callback))

-- Pending roots are not in the registry until their intersection callback
-- mounts them. Reconcile that separate set as well: a route patch can remove
-- a below-fold root without ever producing a registry entry for it.
reconcilePending :: JSVal -> IO ()
reconcilePending observer = do
  pending <- readIORef pendingRef
  current <- mapM isDitherRoot pending
  forM_ [ root | (root, False) <- zip pending current ] $
    unobservePending observer

-- | Reconcile targets that have been observed but have not crossed the
-- viewport threshold. 'isConnected' alone is insufficient: a Miso patch can
-- leave a node attached while removing its dither-root attribute.
isDitherRoot :: JSVal -> IO Bool
isDitherRoot root = do
  connected <- fromJSValUnchecked =<< root ! "isConnected"
  matches <- fromJSValUnchecked =<< (root # "matches" $ Config.ditheredImageSelector)
  pure (connected && matches)

sameNode :: JSVal -> JSVal -> IO Bool
sameNode left right = fromJSValUnchecked =<< (left # "isSameNode" $ [right])

pendingMember :: JSVal -> IO Bool
pendingMember root = do
  pending <- readIORef pendingRef
  or <$> mapM (sameNode root) pending

trackPending :: JSVal -> JSVal -> IO ()
trackPending observer root = do
  initialized <- readInitialized root
  alreadyPending <- pendingMember root
  unless (initialized || alreadyPending) $ do
    void $ observer # "observe" $ [root]
    modifyIORef' pendingRef (root :)

unobservePending :: JSVal -> JSVal -> IO ()
unobservePending observer root = do
  void $ observer # "unobserve" $ [root]
  forgetPending root

-- | Drop a target from the pending set without unobserving it. Mounted roots
-- stay observed: the same observer now drives the visible/invisible pause.
forgetPending :: JSVal -> IO ()
forgetPending root = do
  pending <- readIORef pendingRef
  remaining <- filterM (fmap not . sameNode root) pending
  writeIORef pendingRef remaining

-- | Re-observing an already observed target is a no-op, so this is safe to
-- call on every registry pass.
observeRoot :: JSVal -> JSVal -> IO ()
observeRoot observer root = void $ observer # "observe" $ [root]

-- | The registry entry owning a root, if it is mounted.
entryForRoot :: JSVal -> IO (Maybe Entry)
entryForRoot root = do
  entries <- readIORef registryRef
  listToMaybe <$> filterM (\entry -> sameNode root (entryRoot entry)) entries

-- | Pause the ~20fps loop while a root is off screen and resume it on the way
-- back. Rendering the first frame here also raises @data-dither-ready@ before
-- the image is visible, because the observer margin is a full viewport.
setVisible :: JSVal -> Bool -> IO ()
setVisible root visible = do
  entry <- entryForRoot root
  forM_ entry $ \Entry {..} ->
    forM_ entryLive $ \live -> do
      state <- readIORef (liveState live)
      when (dsVisible state /= visible) $ do
        writeIORef (liveState live) state { dsVisible = visible }
        if visible
          then do
            redrawNow live
            unless (liveReduceMotion live) (startLoop live)
          else stopLoop live

-- | One observer for all dither roots. Its intersection callback drives the
-- visible/invisible pause; mounting happens in 'mountNearby' because the
-- scroll container clips everything outside its box and a root margin has
-- nothing to expand.
ensureVisibilityObserver :: IO ()
ensureVisibilityObserver = do
  existing <- readIORef visibilityObserverRef
  case existing of
    Just _  -> pure ()
    Nothing -> do
      observerClass <- jsg "IntersectionObserver"
      unsupported <- isAbsent observerClass
      unless unsupported $ do
        callback <- syncCallback1 $ \entries -> do
          count <- int entries "length"
          forM_ [0 .. count - 1] $ \index -> do
            entry <- entries !! index
            target <- entry ! "target"
            intersecting <- fromJSValUnchecked =<< entry ! "isIntersecting"
            current <- isDitherRoot target
            when current (setVisible target intersecting)
        options <- create
        observer <- new observerClass (callback, options)
        writeIORef visibilityObserverRef (Just observer)

-- | Mount every pending root within one screen of the scroll container, and
-- do it again on every scroll event. This is the only way to prepare a root
-- that the container is still clipping.
mountNearby :: IO ()
mountNearby = do
  pending <- readIORef pendingRef
  forM_ pending $ \root -> do
    reachable <- withinReach root
    when reachable $ do
      current <- isDitherRoot root
      when current $ do
        forgetPending root
        mountOne root
        -- The observer only reports changes. A root mounted while it is
        -- already off screen would otherwise never receive a pause.
        onScreen <- isOnScreen root
        setVisible root onScreen

-- | Whether the root is within the visible box plus one box of slack, in the
-- page's scroll container (or the viewport when the page has none).
withinReach :: JSVal -> IO Bool
withinReach target = do
  (containerTop, containerBottom) <- visibleBox
  rect <- target # "getBoundingClientRect" $ ()
  top <- number rect "top"
  bottom <- number rect "bottom"
  let height = containerBottom - containerTop
  pure (bottom > containerTop - height && top < containerBottom + height)

-- | Whether the root overlaps the visible box itself, with no slack.
isOnScreen :: JSVal -> IO Bool
isOnScreen target = do
  (containerTop, containerBottom) <- visibleBox
  rect <- target # "getBoundingClientRect" $ ()
  top <- number rect "top"
  bottom <- number rect "bottom"
  pure (bottom > containerTop && top < containerBottom)

-- | The scroll container's visible box, or the viewport when the page has no
-- container (the 404 shell).
visibleBox :: IO (Double, Double)
visibleBox = do
  document <- jsg "document"
  scroller <- document # "querySelector" $ Config.contentScrollSelector
  absent <- isAbsent scroller
  if absent
    then do
      window <- jsg "window"
      height <- number window "innerHeight"
      pure (0, height)
    else do
      container <- scroller # "getBoundingClientRect" $ ()
      top <- number container "top"
      bottom <- number container "bottom"
      pure (top, bottom)
-- | Mark a root and attempt the mount. The marker is written first so a
-- concurrent sync cannot double-mount; a failed preparation leaves it in
-- place with the fallback image visible.
mountOne :: JSVal -> IO ()
mountOne root = do
  void $ root # "setAttribute" $ ("data-" <> Config.ditherInitializedKey, "true" :: MisoString)
  image <- root # "querySelector" $ Config.ditheredSourceSelector
  canvas <- root # "querySelector" $ Config.ditheredCanvasSelector
  imageAbsent <- isAbsent image
  canvasAbsent <- isAbsent canvas
  live <- if imageAbsent || canvasAbsent
    then pure Nothing
    else do
      prepared <- prepareDitherImage canvas
      case prepared of
        Nothing -> do
          void $ root # "setAttribute" $ ("data-" <> Config.ditherFallbackKey, "true" :: MisoString)
          pure Nothing
        Just resources -> Just <$> createLive root image canvas resources
  modifyIORef' registryRef (Entry root live :)
-----------------------------------------------------------------------------
disposeEntry :: Entry -> IO ()
disposeEntry Entry {..} = do
  forM_ entryLive disposeLive
  void $ entryRoot # "removeAttribute" $ ("data-" <> Config.ditherInitializedKey)
  void $ entryRoot # "removeAttribute" $ ("data-" <> Config.ditherReadyKey)
  void $ entryRoot # "removeAttribute" $ ("data-" <> Config.ditherFallbackKey)
-----------------------------------------------------------------------------
readInitialized :: JSVal -> IO Bool
readInitialized root = do
  value <- root # "getAttribute" $ ("data-" <> Config.ditherInitializedKey)
  text <- fromJSValUnchecked value :: IO (Maybe MisoString)
  pure (text == Just "true")
-----------------------------------------------------------------------------
-- | Context, program, textures, buffers and uniforms, in the source's order.
-- 'Nothing' after releasing whatever was created.
prepareDitherImage :: JSVal -> IO (Maybe Resources)
prepareDitherImage canvas = do
  options <- create
  setField options "alpha" True
  setField options "premultipliedAlpha" False
  rawGl <- canvas # "getContext" $ ("webgl" :: MisoString, options)
  absent <- isAbsent rawGl
  if absent
    then pure Nothing
    else do
      program <- compileProgram rawGl ditheredImageVertex ditheredImageFragment "dithered-image"
      case program of
        Nothing -> releaseContext rawGl >> pure Nothing
        Just compiled -> do
          position <- attribLocation rawGl compiled "a_position"
          texCoord <- attribLocation rawGl compiled "a_texCoord"
          if position < 0 || texCoord < 0
            then do
              deleteProgram rawGl compiled
              releaseContext rawGl
              pure Nothing
            else do
              imageTexture <- rawGl # "createTexture" $ ()
              bayerTexture <- rawGl # "createTexture" $ ()
              positionBuffer <- rawGl # "createBuffer" $ ()
              textureBuffer <- rawGl # "createBuffer" $ ()
              anyAbsent <- or <$> mapM isAbsent [imageTexture, bayerTexture, positionBuffer, textureBuffer]
              if anyAbsent
                then do
                  forM_ [imageTexture, bayerTexture] $ \texture ->
                    unlessM (isAbsent texture) (void $ rawGl # "deleteTexture" $ [texture])
                  forM_ [positionBuffer, textureBuffer] $ \buffer ->
                    unlessM (isAbsent buffer) (void $ rawGl # "deleteBuffer" $ [buffer])
                  deleteProgram rawGl compiled
                  releaseContext rawGl
                  pure Nothing
                else do
                  setupState rawGl compiled position texCoord
                    imageTexture bayerTexture positionBuffer textureBuffer
                  resolution <- uniformLocation rawGl compiled "u_resolution"
                  time <- uniformLocation rawGl compiled "u_time"
                  ink <- uniformLocation rawGl compiled "u_ink"
                  pure (Just Resources
                    { resGl = rawGl
                    , resProgram = compiled
                    , resImageTexture = imageTexture
                    , resBayerTexture = bayerTexture
                    , resPositionBuffer = positionBuffer
                    , resTextureBuffer = textureBuffer
                    , resPositionAt = position
                    , resTexCoordAt = texCoord
                    , resResolution = resolution
                    , resTime = time
                    , resInk = ink
                    })
-----------------------------------------------------------------------------
setupState
  :: JSVal -> GlProgram -> Int -> Int
  -> JSVal -> JSVal -> JSVal -> JSVal -> IO ()
setupState gl program position texCoord imageTexture bayerTexture positionBuffer textureBuffer = do
  void $ gl # "useProgram" $ [glProgram program]
  void $ gl # "bindBuffer" $ (glArrayBuffer, positionBuffer)
  quad <- toJSVal (quadVertices :: [Int])
  quadArray <- new (jsg "Float32Array") quad
  void $ gl # "bufferData" $ (glArrayBuffer, quadArray, glStaticDraw)
  void $ gl # "enableVertexAttribArray" $ [position]
  void $ gl # "vertexAttribPointer" $ (position, 2 :: Int, glFloat, False, 0 :: Int, 0 :: Int)
  void $ gl # "bindBuffer" $ (glArrayBuffer, textureBuffer)
  void $ gl # "enableVertexAttribArray" $ [texCoord]
  void $ gl # "activeTexture" $ [glTexture1]
  void $ gl # "bindTexture" $ (glTexture2D, bayerTexture)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureWrapS, glRepeat)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureWrapT, glRepeat)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureMinFilter, glNearest)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureMagFilter, glNearest)
  bayer <- toJSVal (bayerMatrix :: [Int])
  bayerArray <- new (jsg "Uint8Array") bayer
  texImage2DWith gl glTexture2D 0 glLuminance 4 4 0 glLuminance glUnsignedByte bayerArray
  uniform1i gl program "u_bayer" 1
  void $ gl # "activeTexture" $ [glTexture0]
  void $ gl # "bindTexture" $ (glTexture2D, imageTexture)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureWrapS, glClampToEdge)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureWrapT, glClampToEdge)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureMinFilter, glLinear)
  void $ gl # "texParameteri" $ (glTexture2D, glTextureMagFilter, glLinear)
  uniform1i gl program "u_image" 0
-----------------------------------------------------------------------------
createLive :: JSVal -> JSVal -> JSVal -> Resources -> IO Live
createLive root image canvas resources = do
  reduceMotion <- prefersReducedMotion
  state <- newIORef (DitherState 0.0 False False False True False)
  resourcesRef <- newIORef (Just resources)
  ink <- newIORef fallbackColor
  rafCallback <- newIORef jsNull
  rafHandle <- newIORef Nothing
  listeners <- newIORef []
  observers <- newIORef []
  let live = Live
        { liveRoot = root
        , liveImage = image
        , liveCanvas = canvas
        , liveResources = resourcesRef
        , liveReduceMotion = reduceMotion
        , liveState = state
        , liveInk = ink
        , liveRafCallback = rafCallback
        , liveRafHandle = rafHandle
        , liveListeners = listeners
        , liveObservers = observers
        }
  callback <- syncCallback1 $ \timestamp -> tick live timestamp
  writeIORef rafCallback callback
  registerResize live
  registerTheme live
  registerImageLoad live
  registerContextLost live
  refreshInk live
  complete <- imageComplete image
  when complete (loadImage live)
  pure live
-----------------------------------------------------------------------------
-- | The ink color only changes with the theme, so it is read once here and
-- refreshed when the theme observer fires -- the original mount forced a
-- style recalculation on every frame.
refreshInk :: Live -> IO ()
refreshInk live = do
  value <- computedStyleValue (liveRoot live) "--dither-ink"
  writeIORef (liveInk live) (ditherColor value)
-----------------------------------------------------------------------------
registerResize :: Live -> IO ()
registerResize live = do
  callback <- syncCallback1 $ \_ -> do
    resizeCanvas live
    redrawNow live
  observer <- new (jsg "ResizeObserver") callback
  void $ observer # "observe" $ [liveRoot live]
  modifyIORef' (liveObservers live) (observer :)
-----------------------------------------------------------------------------
registerTheme :: Live -> IO ()
registerTheme live = do
  document <- jsg "document"
  element <- document ! "documentElement"
  callback <- syncCallback1 $ \_ -> do
    refreshInk live
    timestamp <- performanceNow
    renderAt live timestamp
  options <- create
  setField options "attributes" True
  observer <- new (jsg "MutationObserver") callback
  void $ observer # "observe" $ (element, options)
  modifyIORef' (liveObservers live) (observer :)
-----------------------------------------------------------------------------
registerImageLoad :: Live -> IO ()
registerImageLoad live = do
  callback <- syncCallback1 $ \_ -> loadImage live
  void $ liveImage live # "addEventListener" $ ("load" :: MisoString, callback)
  modifyIORef' (liveListeners live)
    (Listener (liveImage live) "load" callback False :)
-----------------------------------------------------------------------------
-- | Other canvases hold contexts too, and browsers cap how many can be live.
-- If this one is dropped, show the plain image rather than an empty box.
registerContextLost :: Live -> IO ()
registerContextLost live = do
  lostCallback <- syncCallback1 $ \event -> handleContextLost live event
  void $ liveCanvas live # "addEventListener" $ ("webglcontextlost" :: MisoString, lostCallback)
  modifyIORef' (liveListeners live)
    (Listener (liveCanvas live) "webglcontextlost" lostCallback False :)
  restoredCallback <- syncCallback1 $ \_ -> handleContextRestored live
  void $ liveCanvas live # "addEventListener" $ ("webglcontextrestored" :: MisoString, restoredCallback)
  modifyIORef' (liveListeners live)
    (Listener (liveCanvas live) "webglcontextrestored" restoredCallback False :)
-----------------------------------------------------------------------------
handleContextLost :: Live -> JSVal -> IO ()
handleContextLost live event = do
  state <- readIORef (liveState live)
  unless (dsDisposed state) $ do
    -- The browser only attempts automatic restoration when the loss event is
    -- cancelled. Keep the source image visible while the context is away.
    void $ event # "preventDefault" $ ()
    writeIORef (liveState live) state
      { dsLastFrame = 0.0
      , dsLost = True
      , dsUploaded = False
      , dsReady = False
      }
    stopLoop live
    void $ liveRoot live # "removeAttribute" $ ("data-" <> Config.ditherReadyKey)
    void $ liveRoot live # "setAttribute" $
      ("data-" <> Config.ditherFallbackKey, "true" :: MisoString)

-- | Rebuild the resources invalidated by a context loss. The DOM node and its
-- observers remain owned by the same entry, so a restored image does not
-- accumulate listeners or a second registry entry.
handleContextRestored :: Live -> IO ()
handleContextRestored live = do
  state <- readIORef (liveState live)
  when (dsLost state && not (dsDisposed state)) $ do
    prepared <- prepareDitherImage (liveCanvas live)
    case prepared of
      Nothing -> pure ()
      Just resources -> do
        writeIORef (liveResources live) (Just resources)
        writeIORef (liveState live) state
          { dsLastFrame = 0.0
          , dsLost = False
          , dsUploaded = False
          , dsReady = False
          }
        void $ liveRoot live # "removeAttribute" $ ("data-" <> Config.ditherFallbackKey)
        refreshInk live
        complete <- imageComplete (liveImage live)
        when complete (loadImage live)
-----------------------------------------------------------------------------
loadImage :: Live -> IO ()
loadImage live = do
  state <- readIORef (liveState live)
  (width, height) <- imageNaturalSize (liveImage live)
  when (not (dsDisposed state) && not (dsLost state) && width > 0 && height > 0) $ do
    (_, rootHeight) <- elementBounds (liveRoot live)
    when (rootHeight == 0) (setAspectRatio (liveRoot live) width height)
    setAspectRatio (liveCanvas live) width height
    uploadImage live
    resizeCanvas live
    -- Draw the first frame immediately after the image upload. The source
    -- image remains visible until this succeeds, but it no longer waits for a
    -- second animation-frame turn before the canvas can take over.
    redrawNow live
    unless (liveReduceMotion live) (startLoop live)
-----------------------------------------------------------------------------
uploadImage :: Live -> IO ()
uploadImage live = do
  resources <- readIORef (liveResources live)
  forM_ resources $ \Resources {..} -> do
    let gl = resGl
    -- UNPACK_FLIP_Y_WEBGL only applies to the image upload. Setting it before
    -- the typed-array Bayer upload makes WebGL warn in some browsers.
    void $ gl # "pixelStorei" $ (glUnpackFlipY, 1 :: Int)
    void $ gl # "bindTexture" $ (glTexture2D, resImageTexture)
    void $ gl # "texImage2D" $
      (glTexture2D, 0 :: Int, glRgba, glRgba, glUnsignedByte, liveImage live)
    state <- readIORef (liveState live)
    writeIORef (liveState live) state { dsUploaded = True }
-----------------------------------------------------------------------------
resizeCanvas :: Live -> IO ()
resizeCanvas live = do
  (width, height) <- elementBounds (liveRoot live)
  (sourceWidth, sourceHeight) <- imageNaturalSize (liveImage live)
  when (width > 0 && height > 0 && sourceWidth > 0 && sourceHeight > 0) $ do
    ratio <- devicePixelRatio
    let layout = ditherLayout DitherLayoutInput
          { dliWidth = width
          , dliHeight = height
          , dliDevicePixelRatio = ratio
          , dliSourceWidth = sourceWidth
          , dliSourceHeight = sourceHeight
          }
    applyResize live layout
-----------------------------------------------------------------------------
applyResize :: Live -> DitherLayout -> IO ()
applyResize live layout = do
  state <- readIORef (liveState live)
  resources <- readIORef (liveResources live)
  forM_ resources $ \Resources {..} -> do
    let canvas = liveCanvas live
        canvasWidth = dlCanvasWidth layout
        canvasHeight = dlCanvasHeight layout
    setField canvas "width" canvasWidth
    setField canvas "height" canvasHeight
    -- Assigning either dimension clears the drawing buffer and can reset
    -- vertex/program bindings. Re-establish the complete static GL state,
    -- including the Bayer texture, before applying the new coordinates.
    void $ resGl # "pixelStorei" $ (glUnpackFlipY, 0 :: Int)
    setupState resGl resProgram resPositionAt resTexCoordAt
      resImageTexture resBayerTexture resPositionBuffer resTextureBuffer
    -- The image texture normally survives a canvas resize, but re-upload it
    -- when it was valid so a browser that clears texture state cannot produce
    -- a ready marker for an empty framebuffer.
    when (dsUploaded state) (uploadImage live)
    style <- canvas ! "style"
    setField style "width" (ms (show (dlCssWidth layout)) <> "px")
    setField style "height" (ms (show (dlCssHeight layout)) <> "px")
    void $ resGl # "viewport" $ (0 :: Int, 0 :: Int, canvasWidth, canvasHeight)
    void $ resGl # "uniform2f" $
      (resResolution, fromIntegral canvasWidth :: Double, fromIntegral canvasHeight :: Double)
    void $ resGl # "bindBuffer" $ (glArrayBuffer, resTextureBuffer)
    coordinates <- toJSVal (dlTextureCoordinates layout)
    coordinateArray <- new (jsg "Float32Array") coordinates
    void $ resGl # "bufferData" $ (glArrayBuffer, coordinateArray, glStaticDraw)
    void $ resGl # "vertexAttribPointer" $
      (resTexCoordAt, 2 :: Int, glFloat, False, 0 :: Int, 0 :: Int)
-----------------------------------------------------------------------------
-- | ResizeObserver delivery writes a new canvas backing store, which clears
-- the previous pixels. Redraw unconditionally after that write, but only once
-- the image texture has actually been uploaded; a ready marker must never be
-- the sole evidence that a valid frame exists.
redrawNow :: Live -> IO ()
redrawNow live = do
  state <- readIORef (liveState live)
  (width, height) <- elementBounds (liveRoot live)
  (sourceWidth, sourceHeight) <- imageNaturalSize (liveImage live)
  when ( not (dsDisposed state)
      && not (dsLost state)
      && dsUploaded state
      && width > 0
      && height > 0
      && sourceWidth > 0
      && sourceHeight > 0
      ) $ do
    timestamp <- performanceNow
    ink <- readIORef (liveInk live)
    resources <- readIORef (liveResources live)
    forM_ resources $ \value -> do
      drawFrame value (timestamp / 1000.0) ink
      writeIORef (liveState live)
        state { dsLastFrame = timestamp, dsReady = True }
      -- One attribute write per mounted image, not one per frame: the CSS
      -- crossfade and the pre-dither placeholder both key off this.
      unless (dsReady state) $
        void $ liveRoot live # "setAttribute" $
          ("data-" <> Config.ditherReadyKey, "true" :: MisoString)
-----------------------------------------------------------------------------
-- | Drawing is gated to ~20fps; the loop keeps scheduling in between. With
-- reduced motion one frame is enough, so the tick stops itself.
tick :: Live -> JSVal -> IO ()
tick live rawTimestamp = do
  timestamp <- fromJSValUnchecked rawTimestamp
  state <- readIORef (liveState live)
  (sourceWidth, _) <- imageNaturalSize (liveImage live)
  unless
    ( dsDisposed state
      || dsLost state
      || not (dsUploaded state)
      || not (dsVisible state)
      || sourceWidth == 0
    ) $ do
    renderAt live timestamp
    unless (liveReduceMotion live) (scheduleFrame live)
-----------------------------------------------------------------------------
renderAt :: Live -> Double -> IO ()
renderAt live timestamp = do
  state <- readIORef (liveState live)
  (sourceWidth, _) <- imageNaturalSize (liveImage live)
  when (not (dsDisposed state) && not (dsLost state) && dsUploaded state && sourceWidth > 0) $
    when (shouldDrawFrame (liveReduceMotion live) timestamp (dsLastFrame state)) $ do
      writeIORef (liveState live) state { dsLastFrame = timestamp }
      ink <- readIORef (liveInk live)
      resources <- readIORef (liveResources live)
      forM_ resources $ \value -> drawFrame value (timestamp / 1000.0) ink
-----------------------------------------------------------------------------
drawFrame :: Resources -> Double -> Rgb -> IO ()
drawFrame Resources {..} time ink = do
  void $ resGl # "useProgram" $ [glProgram resProgram]
  void $ resGl # "uniform1f" $ (resTime, time)
  void $ resGl # "uniform3f" $ (resInk, rgbRed ink, rgbGreen ink, rgbBlue ink)
  void $ resGl # "drawArrays" $ (glTriangleStrip, 0 :: Int, 4 :: Int)
-----------------------------------------------------------------------------
startLoop :: Live -> IO ()
startLoop live = do
  state <- readIORef (liveState live)
  when (dsVisible state) $ do
    stopLoop live
    scheduleFrame live
-----------------------------------------------------------------------------
stopLoop :: Live -> IO ()
stopLoop live = do
  handle <- readIORef (liveRafHandle live)
  forM_ handle $ \value -> do
    window <- jsg "window"
    void $ window # "cancelAnimationFrame" $ [value]
  writeIORef (liveRafHandle live) Nothing
-----------------------------------------------------------------------------
scheduleFrame :: Live -> IO ()
scheduleFrame live = do
  callback <- readIORef (liveRafCallback live)
  window <- jsg "window"
  raw <- window # "requestAnimationFrame" $ [callback]
  handle <- fromJSValUnchecked raw
  writeIORef (liveRafHandle live) (Just handle)
-----------------------------------------------------------------------------
-- | Release one instance: mark it disposed, stop the loop, drop listeners
-- and observers, delete the GL resources and free the context.
disposeLive :: Live -> IO ()
disposeLive live = do
  state <- readIORef (liveState live)
  writeIORef (liveState live) state { dsDisposed = True }
  stopLoop live
  listeners <- readIORef (liveListeners live)
  forM_ (reverse listeners) $ \Listener {..} ->
    void $ listenerTarget # "removeEventListener" $
      (listenerType, listenerCallback, listenerCapture)
  observers <- readIORef (liveObservers live)
  forM_ observers $ \observer -> void $ observer # "disconnect" $ ()
  resources <- readIORef (liveResources live)
  writeIORef (liveResources live) Nothing
  forM_ resources $ \Resources {..} -> do
    void $ resGl # "deleteTexture" $ [resImageTexture]
    void $ resGl # "deleteTexture" $ [resBayerTexture]
    void $ resGl # "deleteBuffer" $ [resPositionBuffer]
    void $ resGl # "deleteBuffer" $ [resTextureBuffer]
    deleteProgram resGl resProgram
    releaseContext resGl
-----------------------------------------------------------------------------
attribLocation :: JSVal -> GlProgram -> MisoString -> IO Int
attribLocation gl program name = do
  value <- gl # "getAttribLocation" $ (glProgram program, name)
  fromJSValUnchecked value
-----------------------------------------------------------------------------
uniformLocation :: JSVal -> GlProgram -> MisoString -> IO JSVal
uniformLocation gl program name =
  gl # "getUniformLocation" $ (glProgram program, name)
-----------------------------------------------------------------------------
uniform1i :: JSVal -> GlProgram -> MisoString -> Int -> IO ()
uniform1i gl program name value = do
  location <- uniformLocation gl program name
  void $ gl # "uniform1i" $ (location, value)
-----------------------------------------------------------------------------
elementBounds :: JSVal -> IO (Double, Double)
elementBounds element = do
  rect <- element # "getBoundingClientRect" $ ()
  width <- number rect "width"
  height <- number rect "height"
  pure (width, height)
-----------------------------------------------------------------------------
imageNaturalSize :: JSVal -> IO (Double, Double)
imageNaturalSize image = do
  width <- number image "naturalWidth"
  height <- number image "naturalHeight"
  pure (width, height)
-----------------------------------------------------------------------------
imageComplete :: JSVal -> IO Bool
imageComplete image = do
  value <- image ! "complete"
  fromJSValUnchecked value
-----------------------------------------------------------------------------
devicePixelRatio :: IO Double
devicePixelRatio = do
  window <- jsg "window"
  number window "devicePixelRatio"
-----------------------------------------------------------------------------
computedStyleValue :: JSVal -> MisoString -> IO MisoString
computedStyleValue element property = do
  window <- jsg "window"
  style <- window # "getComputedStyle" $ [element]
  value <- style # "getPropertyValue" $ (property :: MisoString)
  fromJSValUnchecked value
-----------------------------------------------------------------------------
-- | The natural size as a CSS @aspect-ratio@, so a cover with no height yet
-- reserves the right box before the texture arrives.
setAspectRatio :: JSVal -> Double -> Double -> IO ()
setAspectRatio element width height = do
  style <- element ! "style"
  setField style "aspectRatio" (ms (show width) <> " / " <> ms (show height))
-----------------------------------------------------------------------------
unlessM :: IO Bool -> IO () -> IO ()
unlessM condition action = condition >>= \result -> unless result action
