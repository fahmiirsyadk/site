module Platform.Browser.DitheredImage
  ( DitherUniforms
  , PreparedDitherImage
  , disposeDitherImage
  , drawDitherImage
  , mountDitheredImage
  , prepareDitherImage
  , resizeDitherImage
  , uploadDitherImage
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Foldkit.Mount (Element)
import Platform.Browser (Cleanup)
import Platform.Browser.Sensors as Sensors
import PursTs.Effect as Fx
import Runtime.Dither as Dither

foreign import data PreparedDitherImage :: Type

foreign import prepareDitherImage
  :: Element
  -> Array Number
  -> Array Int
  -> Fx.Effect Fx.Never Fx.NoServices (Array PreparedDitherImage)

foreign import uploadDitherImage :: PreparedDitherImage -> Element -> Unit
foreign import resizeDitherImage :: PreparedDitherImage -> Dither.DitherLayout -> Unit
foreign import drawDitherImage :: PreparedDitherImage -> DitherUniforms -> Unit
foreign import disposeDitherImage :: PreparedDitherImage -> Cleanup

type DitherUniforms =
  { time :: Number
  , red :: Number
  , green :: Number
  , blue :: Number
  }

type RootState =
  { lastFrame :: Number
  , disposed :: Boolean
  }

type RegistryEntry = { root :: Element, cleanup :: Cleanup }

type DitherContext =
  { root :: Element
  , image :: Element
  , canvas :: Element
  , handle :: PreparedDitherImage
  , reduceMotion :: Boolean
  , stateCell :: Sensors.Cell RootState
  , inkCell :: Sensors.Cell Dither.Rgb
  , loopCell :: Sensors.Cell Cleanup
  }

noopCleanup :: Cleanup
noopCleanup = Sensors.composeCleanups []

-- | Mounts either a single dithered root (when the element itself carries
-- | `data-dithered-image`) or a container: every matching descendant is
-- | mounted, and a subtree observer keeps the registry in step with the
-- | client-side navigation that swaps the container's content in place.
mountDitheredImage :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountDitheredImage element = do
  self <- Sensors.matchesSelector element "[data-dithered-image]"
  if self then mountOne element else mountContainer element

mountContainer :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountContainer element = do
  registryCell <- Sensors.newCell ([] :: Array RegistryEntry)
  initialRoots <- Sensors.selectElements element "[data-dithered-image]"
  Sensors.forEach initialRoots (addRoot registryCell)
  contentCleanup <- Sensors.observeChildList element \delta -> do
    Sensors.forEach delta.added (addIfRoot registryCell)
    Sensors.forEach delta.removed (removeRoot registryCell)
  pure
    (Sensors.composeCleanups
      [ contentCleanup
      , Sensors.cleanupOfEffect (disposeRegistry registryCell)
      ])

addRoot :: Sensors.Cell (Array RegistryEntry) -> Element -> Fx.Effect Fx.Never Fx.NoServices Unit
addRoot registryCell root = do
  known <- rootRegistered registryCell root
  if known then pure unit else do
    cleanup <- mountOne root
    entries <- Sensors.readCell registryCell
    Sensors.writeCell registryCell (Array.cons { root, cleanup } entries)

-- | Only elements carrying the marker become roots; the observer reports
-- | every element in an added or removed subtree.
addIfRoot :: Sensors.Cell (Array RegistryEntry) -> Element -> Fx.Effect Fx.Never Fx.NoServices Unit
addIfRoot registryCell candidate = do
  matches <- Sensors.matchesSelector candidate "[data-dithered-image]"
  if matches then addRoot registryCell candidate else pure unit

removeRoot :: Sensors.Cell (Array RegistryEntry) -> Element -> Fx.Effect Fx.Never Fx.NoServices Unit
removeRoot registryCell root = do
  entries <- Sensors.readCell registryCell
  let taken = takeRoot entries root
  Sensors.writeCell registryCell taken.kept
  case taken.entry of
    Nothing -> pure unit
    Just entry -> Sensors.runCleanup entry.cleanup

disposeRegistry :: Sensors.Cell (Array RegistryEntry) -> Fx.Effect Fx.Never Fx.NoServices Unit
disposeRegistry registryCell = do
  entries <- Sensors.readCell registryCell
  Sensors.writeCell registryCell []
  Sensors.forEach entries (\entry -> Sensors.runCleanup entry.cleanup)

rootRegistered
  :: Sensors.Cell (Array RegistryEntry)
  -> Element
  -> Fx.Effect Fx.Never Fx.NoServices Boolean
rootRegistered registryCell root = do
  entries <- Sensors.readCell registryCell
  pure (Array.any (\entry -> Sensors.elementsEqual entry.root root) entries)

-- | Splits the registry around the entry whose root is the given element.
-- | Non-recursive so the backend emits an annotated (non-circular) signature.
takeRoot :: Array RegistryEntry -> Element -> { entry :: Maybe RegistryEntry, kept :: Array RegistryEntry }
takeRoot entries root = case Array.findIndex (\entry -> Sensors.elementsEqual entry.root root) entries of
  Nothing -> { entry: Nothing, kept: entries }
  Just at -> case Array.splitAt at entries of
    { before, after } -> { entry: Array.head after, kept: before <> Array.drop 1 after }

-- | Mounts one dithered root, guarded by the `ditherInitialized` marker. The
-- | marker (and the fallback flag) are cleared again on unmount so a remount
-- | starts clean.
mountOne :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountOne root = do
  initialized <- Sensors.readDataAttribute root "ditherInitialized"
  if initialized == "true" then pure noopCleanup else do
    Sensors.writeDataFlag root "ditherInitialized" true
    dispose <- mountRoot root
    pure
      (Sensors.composeCleanups
        [ dispose
        , Sensors.cleanupOfEffect (Sensors.writeDataFlag root "ditherInitialized" false)
        , Sensors.cleanupOfEffect (Sensors.writeDataFlag root "ditherFallback" false)
        ])

mountRoot :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountRoot root = do
  imageFound <- Sensors.findElement root "img[data-dithered-source]"
  canvasFound <- Sensors.findElement root "canvas[data-dithered-canvas]"
  case imageFound, canvasFound of
    [image], [canvas] -> mountPrepared root image canvas
    _, _ -> pure noopCleanup

mountPrepared
  :: Element
  -> Element
  -> Element
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountPrepared root image canvas = do
  prepared <- prepareDitherImage canvas Dither.quadVertices Dither.bayerMatrix
  case Array.head prepared of
    Nothing -> do
      Sensors.writeDataFlag root "ditherFallback" true
      pure noopCleanup
    Just handle -> mountDitherObservers root image canvas handle

mountDitherObservers
  :: Element -> Element -> Element -> PreparedDitherImage -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountDitherObservers root image canvas handle = do
  reduceMotion <- Sensors.prefersReducedMotion
  stateCell <- Sensors.newCell { lastFrame: 0.0, disposed: false }
  inkCell <- Sensors.newCell Dither.fallbackColor
  loopCell <- Sensors.newCell noopCleanup
  let
    context = { root, image, canvas, handle, reduceMotion, stateCell, inkCell, loopCell }
  cleanups <- wireDitherObservers context
  refreshDitherInk context
  complete <- Sensors.imageComplete image
  if complete then loadDitherImage context else pure unit
  pure
    (Sensors.composeCleanups
      [ Sensors.cleanupOfCell context.loopCell
      , cleanups
      , disposeDitherImage handle
      ])

-- | The ink color only changes with the theme, so it is read once and
-- | refreshed when the theme observer fires — the original mount forced a
-- | style recalculation on every frame.
refreshDitherInk :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Unit
refreshDitherInk context = do
  value <- Sensors.computedStyleValue context.root "--dither-ink"
  Sensors.writeCell context.inkCell (Dither.ditherColor value)

resizeDitherCanvas :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Unit
resizeDitherCanvas context = do
  bounds <- Sensors.elementBounds context.root
  if bounds.width == 0.0 || bounds.height == 0.0 then pure unit else do
    ratio <- Sensors.devicePixelRatio
    natural <- Sensors.imageNaturalSize context.image
    let
      layout =
        Dither.ditherLayout
          { width: bounds.width
          , height: bounds.height
          , devicePixelRatio: ratio
          , sourceWidth: natural.width
          , sourceHeight: natural.height
          }
    Fx.sync \_ -> resizeDitherImage context.handle layout

renderDitherAt :: DitherContext -> Number -> Fx.Effect Fx.Never Fx.NoServices Unit
renderDitherAt context timestamp = do
  state <- Sensors.readCell context.stateCell
  natural <- Sensors.imageNaturalSize context.image
  if state.disposed || natural.width == 0.0 then pure unit else
    if
      Dither.shouldDrawFrame
        { reduceMotion: context.reduceMotion
        , timestamp
        , previousTimestamp: state.lastFrame
        }
    then do
      Sensors.writeCell context.stateCell state { lastFrame = timestamp }
      ink <- Sensors.readCell context.inkCell
      Fx.sync \_ ->
        drawDitherImage
          context.handle
          { time: timestamp / 1000.0
          , red: ink.red
          , green: ink.green
          , blue: ink.blue
          }
    else pure unit

-- | Drawing is gated to ~20fps; the loop keeps scheduling in between. With
-- | reduced motion one frame is enough, so the tick stops itself.
ditherTick :: DitherContext -> Number -> Fx.Effect Fx.Never Fx.NoServices Boolean
ditherTick context timestamp = do
  state <- Sensors.readCell context.stateCell
  natural <- Sensors.imageNaturalSize context.image
  if state.disposed || natural.width == 0.0 then pure false else do
    renderDitherAt context timestamp
    pure (not context.reduceMotion)

startDitherLoop :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Unit
startDitherLoop context = do
  stopDitherLoop context
  cleanup <- Sensors.startLoop (ditherTick context)
  Sensors.writeCell context.loopCell cleanup

stopDitherLoop :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Unit
stopDitherLoop context = Sensors.readCell context.loopCell >>= Sensors.runCleanup

loadDitherImage :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Unit
loadDitherImage context = do
  natural <- Sensors.imageNaturalSize context.image
  if natural.width == 0.0 || natural.height == 0.0 then pure unit else do
    bounds <- Sensors.elementBounds context.root
    if bounds.height == 0.0 then
      Sensors.setAspectRatio context.root natural.width natural.height
    else pure unit
    Sensors.setAspectRatio context.canvas natural.width natural.height
    Fx.sync \_ -> uploadDitherImage context.handle context.image
    resizeDitherCanvas context
    startDitherLoop context

handleDitherContextLost :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Unit
handleDitherContextLost context = do
  state <- Sensors.readCell context.stateCell
  Sensors.writeCell context.stateCell state { disposed = true }
  stopDitherLoop context
  Sensors.writeDataFlag context.root "ditherFallback" true

wireDitherObservers :: DitherContext -> Fx.Effect Fx.Never Fx.NoServices Cleanup
wireDitherObservers context = do
  resizeCleanup <- Sensors.observeResize context.root (\_ -> resizeDitherCanvas context)
  themeCleanup <- Sensors.observeTheme \_ -> do
    refreshDitherInk context
    now <- Sensors.nowTimestamp
    renderDitherAt context now
  loadCleanup <- Sensors.onImageLoad context.image (loadDitherImage context)
  -- Other canvases on the page also hold contexts, and browsers cap how
  -- many can be live. If this one is dropped, show the plain image rather
  -- than an empty box.
  contextCleanup <- Sensors.onContextLost context.canvas (handleDitherContextLost context)
  pure
    (Sensors.composeCleanups
      [ contextCleanup
      , loadCleanup
      , themeCleanup
      , resizeCleanup
      ])
