module Platform.Browser.HollowMark
  ( HollowPointerEvent
  , HollowState
  , HollowUniforms
  , PreparedHollowMark
  , disposeHollowMark
  , drawHollowMark
  , hollowFrame
  , hollowPointer
  , initialHollowState
  , mountHollowMark
  , prepareHollowMark
  , resizeHollowMark
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Foldkit.Mount (Element)
import Platform.Browser (Cleanup)
import Platform.Browser.Sensors as Sensors
import PursTs.Effect as Fx
import Runtime.Canvas as Canvas
import Runtime.Frame as Frame
import Runtime.HollowGeometry as HollowGeometry
import Runtime.HollowMotion as HollowMotion

foreign import data PreparedHollowMark :: Type

foreign import prepareHollowMark
  :: Element
  -> Array Number
  -> Int
  -> String
  -> Fx.Effect Fx.Never Fx.NoServices (Array PreparedHollowMark)

foreign import resizeHollowMark :: PreparedHollowMark -> Int -> Int -> Unit
foreign import drawHollowMark :: PreparedHollowMark -> HollowUniforms -> Unit
foreign import disposeHollowMark :: PreparedHollowMark -> Cleanup

type HollowUniforms =
  { angle :: Number
  , cubeAngle :: Number
  , aspect :: Number
  , time :: Number
  , labHover :: Number
  }

type HollowState =
  { motion :: HollowMotion.HollowMotion
  , visual :: HollowMotion.HollowVisual
  , previousFrameTime :: Number
  , dragging :: Boolean
  , dragStartX :: Number
  , dragStartAngle :: Number
  , previousPointerX :: Number
  , previousPointerTime :: Number
  }

type HollowPointerEvent =
  { kind :: String
  , x :: Number
  , y :: Number
  , now :: Number
  , width :: Number
  }

type HollowSize = { width :: Int, height :: Int }

type HollowContext =
  { element :: Element
  , handle :: PreparedHollowMark
  , startedAt :: Number
  , reduceMotion :: Boolean
  , stateCell :: Sensors.Cell HollowState
  , hoverCell :: Sensors.Cell Number
  , sizeCell :: Sensors.Cell HollowSize
  , loopCell :: Sensors.Cell Cleanup
  }

moonImage :: String
moonImage = "/assets/images/lroc-color-1k.webp"

labHoverValue :: String -> Number
labHoverValue value = if value == "hovered" then 1.0 else 0.0

initialHollowState :: Number -> HollowState
initialHollowState startedAt =
  { motion: HollowMotion.initialHollowMotion
  , visual: HollowMotion.initialHollowVisual 0.0
  , previousFrameTime: startedAt
  , dragging: false
  , dragStartX: 0.0
  , dragStartAngle: 0.0
  , previousPointerX: 0.0
  , previousPointerTime: 0.0
  }

-- | One frame of the mount: steps the motion state machines the original
-- | TypeScript mount drove and derives the uniform block to submit.
hollowFrame
  :: { timestamp :: Number
     , startedAt :: Number
     , reduceMotion :: Boolean
     , labHoverTarget :: Number
     , dragging :: Boolean
     , canvasWidth :: Int
     , canvasHeight :: Int
     }
  -> HollowState
  -> { state :: HollowState, uniforms :: HollowUniforms }
hollowFrame input state =
  let
    timing =
      Frame.frameTiming
        { timestamp: input.timestamp
        , previousTimestamp: state.previousFrameTime
        , startedAt: input.startedAt
        }

    motion =
      HollowMotion.stepHollowMotion
        { dragging: input.dragging
        , frameDuration: timing.frameDuration
        , reduceMotion: input.reduceMotion
        }
        state.motion

    visual =
      HollowMotion.stepHollowVisual
        { frameDuration: timing.frameDuration
        , labHoverTarget: input.labHoverTarget
        , interactionActive: motion.interactionActive
        , reduceMotion: input.reduceMotion
        }
        state.visual

    cubeRotation =
      HollowMotion.hollowCubeRotation
        { reduceMotion: input.reduceMotion
        , elapsed: timing.seconds
        }
  in
    { state: state
        { motion = motion
        , visual = visual
        , previousFrameTime = input.timestamp
        }
    , uniforms:
        { angle: motion.smoothAngle
        , cubeAngle: cubeRotation
        , aspect: Int.toNumber input.canvasWidth / Int.toNumber input.canvasHeight
        , time: if input.reduceMotion then 0.0 else visual.motionSeconds
        , labHover: visual.labHover
        }
    }

-- | Pointer transitions, mirroring the original handlers exactly.
hollowPointer :: HollowPointerEvent -> HollowState -> HollowState
hollowPointer event state = case event.kind of
  "down" ->
    state
      { motion = HollowMotion.beginHollowDrag state.motion
      , dragging = true
      , dragStartX = event.x
      , dragStartAngle = state.motion.targetAngle
      , previousPointerX = event.x
      , previousPointerTime = event.now
      }
  "move" | state.dragging ->
    let
      drag =
        HollowMotion.hollowDragValues
          { dragStartAngle: state.dragStartAngle
          , dragStartX: state.dragStartX
          , currentX: event.x
          , previousX: state.previousPointerX
          , width: event.width
          , elapsed: event.now - state.previousPointerTime
          }
    in
      state
        { motion = HollowMotion.dragHollow drag state.motion
        , previousPointerX = event.x
        , previousPointerTime = event.now
        }
  "up" ->
    state
      { motion =
          HollowMotion.endHollowDrag
            { stale: event.now - state.previousPointerTime > 80.0 }
            state.motion
      , dragging = false
      }
  _ -> state

noopCleanup :: Cleanup
noopCleanup = Sensors.composeCleanups []

mountHollowMark :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountHollowMark element = do
  prepared <-
    prepareHollowMark element HollowGeometry.hollowVertices HollowGeometry.hollowVertexCount moonImage
  case Array.head prepared of
    Nothing -> pure noopCleanup
    Just handle -> mountHollowReady element handle

mountHollowReady :: Element -> PreparedHollowMark -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountHollowReady element handle = do
  reduceMotion <- Sensors.prefersReducedMotion
  startedAt <- Sensors.nowTimestamp
  initialLab <- Sensors.readDataAttribute element "labInteraction"
  context <- setupHollowCells element handle startedAt (labHoverValue initialLab) reduceMotion
  cleanups <- wireHollowObservers context
  resizeHollowCanvas context
  startHollowLoop context
  pure
    (Sensors.composeCleanups
      [ Sensors.cleanupOfCell context.loopCell
      , cleanups
      , disposeHollowMark handle
      ])

setupHollowCells
  :: Element
  -> PreparedHollowMark
  -> Number
  -> Number
  -> Boolean
  -> Fx.Effect Fx.Never Fx.NoServices HollowContext
setupHollowCells element handle startedAt hover0 reduceMotion = do
  stateCell <- Sensors.newCell ((initialHollowState startedAt) { visual = HollowMotion.initialHollowVisual hover0 })
  hoverCell <- Sensors.newCell hover0
  sizeCell <- Sensors.newCell { width: 1, height: 1 }
  loopCell <- Sensors.newCell (Sensors.composeCleanups [])
  pure
    { element
    , handle
    , startedAt
    , reduceMotion
    , stateCell
    , hoverCell
    , sizeCell
    , loopCell
    }

-- | Element- and document-bound observers. Visibility gates the animation
-- | loop; reduced-motion users get a single rendered frame per change instead.
wireHollowObservers :: HollowContext -> Fx.Effect Fx.Never Fx.NoServices Cleanup
wireHollowObservers context = do
  pointerCleanup <- wireHollowPointer context
  visibilityCleanup <-
    Sensors.observeVisibility 120.0 context.element \visible ->
      if visible then startHollowLoop context else stopHollowLoop context
  resizeCleanup <-
    Sensors.observeResize context.element \_ ->
      resizeHollowCanvas context >>= \_ ->
        if context.reduceMotion then renderHollowNow context else pure unit
  themeCleanup <- Sensors.observeTheme \_ -> renderHollowNow context
  hoverCleanup <-
    Sensors.observeDataAttribute context.element "labInteraction" \value ->
      Sensors.writeCell context.hoverCell (labHoverValue value)
  windowCleanup <- Sensors.onWindowResize (resizeHollowCanvas context)
  pure
    (Sensors.composeCleanups
      [ visibilityCleanup
      , pointerCleanup
      , windowCleanup
      , hoverCleanup
      , themeCleanup
      , resizeCleanup
      ])

wireHollowPointer :: HollowContext -> Fx.Effect Fx.Never Fx.NoServices Cleanup
wireHollowPointer context =
  Sensors.onPointer context.element { capture: true, preventDefault: true } \sample -> do
    now <- Sensors.nowTimestamp
    size <- Sensors.clientSize context.element
    state <- Sensors.readCell context.stateCell
    Sensors.writeCell context.stateCell
      (hollowPointer
        { kind: sample.kind
        , x: sample.x
        , y: sample.y
        , now
        , width: size.width
        }
        state)
    case sample.kind of
      "down" -> Sensors.writeDataFlag context.element "dragging" true
      "up" -> Sensors.writeDataFlag context.element "dragging" false
      _ -> pure unit

resizeHollowCanvas :: HollowContext -> Fx.Effect Fx.Never Fx.NoServices Unit
resizeHollowCanvas context = do
  bounds <- Sensors.elementBounds context.element
  if bounds.width == 0.0 || bounds.height == 0.0 then pure unit else do
    ratio <- Sensors.devicePixelRatio
    let
      layout =
        Canvas.rasterLayout
          { width: bounds.width
          , height: bounds.height
          , devicePixelRatio: ratio
          , minimumPixelRatio: 1.0
          , maximumPixelRatio: 6.0
          }
    Sensors.writeCell context.sizeCell { width: layout.canvasWidth, height: layout.canvasHeight }
    Fx.sync \_ -> resizeHollowMark context.handle layout.canvasWidth layout.canvasHeight

renderHollowAt :: HollowContext -> Number -> Fx.Effect Fx.Never Fx.NoServices Unit
renderHollowAt context timestamp = do
  state <- Sensors.readCell context.stateCell
  hover <- Sensors.readCell context.hoverCell
  size <- Sensors.readCell context.sizeCell
  let
    frame =
      hollowFrame
        { timestamp
        , startedAt: context.startedAt
        , reduceMotion: context.reduceMotion
        , labHoverTarget: hover
        , dragging: state.dragging
        , canvasWidth: size.width
        , canvasHeight: size.height
        }
        state
  Sensors.writeCell context.stateCell frame.state
  Fx.sync \_ -> drawHollowMark context.handle frame.uniforms

renderHollowNow :: HollowContext -> Fx.Effect Fx.Never Fx.NoServices Unit
renderHollowNow context = Sensors.nowTimestamp >>= renderHollowAt context

startHollowLoop :: HollowContext -> Fx.Effect Fx.Never Fx.NoServices Unit
startHollowLoop context = do
  stopHollowLoop context
  cleanup <- Sensors.startLoop (hollowTick context)
  Sensors.writeCell context.loopCell cleanup

stopHollowLoop :: HollowContext -> Fx.Effect Fx.Never Fx.NoServices Unit
stopHollowLoop context = Sensors.readCell context.loopCell >>= Sensors.runCleanup

hollowTick :: HollowContext -> Number -> Fx.Effect Fx.Never Fx.NoServices Boolean
hollowTick context timestamp =
  renderHollowAt context timestamp >>= \_ -> pure true
