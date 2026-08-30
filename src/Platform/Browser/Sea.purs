module Platform.Browser.Sea
  ( PreparedSea
  , SeaPointerEvent
  , SeaState
  , SeaUniforms
  , disposeSea
  , drawSea
  , initialSeaState
  , mountSeaShader
  , prepareSea
  , resizeSea
  , seaFrame
  , seaPointer
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
import Runtime.SeaMotion as SeaMotion

foreign import data PreparedSea :: Type

foreign import prepareSea :: Element -> Fx.Effect Fx.Never Fx.NoServices (Array PreparedSea)
foreign import resizeSea :: PreparedSea -> Int -> Int -> Number -> Unit
foreign import drawSea :: PreparedSea -> SeaUniforms -> Unit
foreign import disposeSea :: PreparedSea -> Cleanup

type SeaUniforms =
  { time :: Number
  , resolutionX :: Number
  , resolutionY :: Number
  , cubeX :: Number
  , cubeY :: Number
  , velocityX :: Number
  , velocityY :: Number
  , uiDark :: Number
  , intro :: Number
  , labHover :: Number
  }

type SeaState =
  { motion :: SeaMotion.SeaMotion
  , previousFrameTime :: Number
  , dragging :: Boolean
  , startX :: Number
  , startY :: Number
  , baseX :: Number
  , baseY :: Number
  }

type SeaPointerEvent =
  { kind :: String
  , x :: Number
  , y :: Number
  , width :: Number
  , height :: Number
  }

type SeaSize = { width :: Int, height :: Int, ratio :: Number }

-- Everything the render loop and observers need; threaded explicitly so each
-- wiring step stays a small named function.
type SeaContext =
  { element :: Element
  , handle :: PreparedSea
  , startedAt :: Number
  , stateCell :: Sensors.Cell SeaState
  , hoverCell :: Sensors.Cell Number
  , darkCell :: Sensors.Cell Boolean
  , sizeCell :: Sensors.Cell SeaSize
  , loopCell :: Sensors.Cell Cleanup
  }

initialSeaState :: Number -> Number -> SeaState
initialSeaState startedAt labHover =
  { motion: SeaMotion.initialSeaMotion { labHover = labHover }
  , previousFrameTime: startedAt
  , dragging: false
  , startX: 0.0
  , startY: 0.0
  , baseX: 0.0
  , baseY: 0.0
  }

labHoverValue :: String -> Number
labHoverValue value = if value == "hovered" then 1.0 else 0.0

-- | One frame of the mount, matching the original render loop's math.
seaFrame
  :: { timestamp :: Number
     , startedAt :: Number
     , dragging :: Boolean
     , labHoverTarget :: Number
     , canvasWidth :: Int
     , canvasHeight :: Int
     , dark :: Boolean
     }
  -> SeaState
  -> { state :: SeaState, uniforms :: SeaUniforms }
seaFrame input state =
  let
    timing =
      Frame.frameTiming
        { timestamp: input.timestamp
        , previousTimestamp: state.previousFrameTime
        , startedAt: input.startedAt
        }

    motion =
      SeaMotion.stepSeaMotion
        { dragging: input.dragging
        , frameDuration: timing.frameDuration
        , labHoverTarget: input.labHoverTarget
        }
        state.motion
  in
    { state: state
        { motion = motion
        , previousFrameTime = input.timestamp
        }
    , uniforms:
        { time: timing.seconds
        , resolutionX: Int.toNumber input.canvasWidth
        , resolutionY: Int.toNumber input.canvasHeight * 1.92
        , cubeX: motion.smoothX
        , cubeY: motion.smoothY
        , velocityX: motion.velocityX
        , velocityY: motion.velocityY
        , uiDark: if input.dark then 1.0 else 0.0
        , intro: timing.intro
        , labHover: motion.labHover
        }
    }

-- | Pointer transitions, mirroring the original handlers exactly.
seaPointer :: SeaPointerEvent -> SeaState -> SeaState
seaPointer event state = case event.kind of
  "down" ->
    state
      { dragging = true
      , startX = event.x
      , startY = event.y
      , baseX = state.motion.targetX
      , baseY = state.motion.targetY
      }
  "move" | state.dragging ->
    state
      { motion =
          SeaMotion.retargetSeaMotion
            (SeaMotion.seaDragTarget
              { baseX: state.baseX
              , baseY: state.baseY
              , startX: state.startX
              , startY: state.startY
              , currentX: event.x
              , currentY: event.y
              , width: event.width
              , height: event.height
              })
            state.motion
      }
  "up" -> state { dragging = false }
  _ -> state

noopCleanup :: Cleanup
noopCleanup = Sensors.composeCleanups []

mountSeaShader :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountSeaShader element = do
  initialized <- Sensors.readDataAttribute element "initialized"
  if initialized == "true" then pure noopCleanup else mountSeaFresh element

mountSeaFresh :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountSeaFresh element = do
  prepared <- prepareSea element
  case Array.head prepared of
    Nothing -> pure noopCleanup
    Just handle -> mountSeaReady element handle

mountSeaReady :: Element -> PreparedSea -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountSeaReady element handle = do
  Sensors.writeDataFlag element "initialized" true
  startedAt <- Sensors.nowTimestamp
  parents <- Sensors.parentElement element
  initialHover <- seaInitialHover parents
  context <- setupSeaCells element handle startedAt initialHover
  cleanups <- wireSeaObservers context parents
  resizeSeaCanvas context
  startSeaLoop context
  pure
    (Sensors.composeCleanups
      [ Sensors.cleanupOfCell context.loopCell
      , cleanups
      , disposeSea handle
      , Sensors.cleanupOfEffect (Sensors.writeDataFlag element "initialized" false)
      ])

seaInitialHover :: Array Element -> Fx.Effect Fx.Never Fx.NoServices Number
seaInitialHover parents = case Array.head parents of
  Nothing -> pure 0.0
  Just parent -> labHoverValue <$> Sensors.readDataAttribute parent "labInteraction"

setupSeaCells
  :: Element
  -> PreparedSea
  -> Number
  -> Number
  -> Fx.Effect Fx.Never Fx.NoServices SeaContext
setupSeaCells element handle startedAt initialHover = do
  stateCell <- Sensors.newCell (initialSeaState startedAt initialHover)
  hoverCell <- Sensors.newCell initialHover
  initiallyDark <- Sensors.isDarkTheme
  darkCell <- Sensors.newCell initiallyDark
  sizeCell <- Sensors.newCell { width: 1, height: 1, ratio: 1.0 }
  loopCell <- Sensors.newCell (Sensors.composeCleanups [])
  pure
    { element
    , handle
    , startedAt
    , stateCell
    , hoverCell
    , darkCell
    , sizeCell
    , loopCell
    }

-- | Element-bound observers: pointer input drives the motion state, resize
-- | re-rasters the canvas, visibility gates the animation loop.
wireSeaObservers
  :: SeaContext
  -> Array Element
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup
wireSeaObservers context parents = do
  pointerCleanup <- wireSeaPointer context
  hoverCleanup <- wireSeaHover context parents
  resizeCleanup <- Sensors.observeResize context.element (\_ -> resizeSeaCanvas context)
  themeCleanup <- Sensors.observeTheme (Sensors.writeCell context.darkCell)
  visibilityCleanup <-
    Sensors.observeVisibility 120.0 context.element \visible ->
      if visible then startSeaLoop context else stopSeaLoop context
  pure
    (Sensors.composeCleanups
      [ visibilityCleanup
      , pointerCleanup
      , hoverCleanup
      , themeCleanup
      , resizeCleanup
      ])

wireSeaPointer :: SeaContext -> Fx.Effect Fx.Never Fx.NoServices Cleanup
wireSeaPointer context =
  Sensors.onPointer context.element { capture: true, preventDefault: true } \sample -> do
    size <- Sensors.clientSize context.element
    state <- Sensors.readCell context.stateCell
    Sensors.writeCell context.stateCell
      (seaPointer
        { kind: sample.kind
        , x: sample.x
        , y: sample.y
        , width: size.width
        , height: size.height
        }
        state)

wireSeaHover :: SeaContext -> Array Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
wireSeaHover context parents = case Array.head parents of
  Nothing -> pure (Sensors.composeCleanups [])
  Just parent ->
    Sensors.observeDataAttribute parent "labInteraction" \value ->
      Sensors.writeCell context.hoverCell (labHoverValue value)

resizeSeaCanvas :: SeaContext -> Fx.Effect Fx.Never Fx.NoServices Unit
resizeSeaCanvas context = do
  bounds <- Sensors.elementBounds context.element
  ratio <- Sensors.devicePixelRatio
  let
    layout =
      Canvas.rasterLayout
        { width: bounds.width
        , height: bounds.height
        , devicePixelRatio: ratio
        , minimumPixelRatio: 1.0
        , maximumPixelRatio: 2.0
        }
  Sensors.writeCell context.sizeCell
    { width: layout.canvasWidth, height: layout.canvasHeight, ratio: layout.pixelRatio }
  Fx.sync \_ ->
    resizeSea context.handle layout.canvasWidth layout.canvasHeight layout.pixelRatio

renderSeaAt :: SeaContext -> Number -> Fx.Effect Fx.Never Fx.NoServices Unit
renderSeaAt context timestamp = do
  state <- Sensors.readCell context.stateCell
  hover <- Sensors.readCell context.hoverCell
  dark <- Sensors.readCell context.darkCell
  size <- Sensors.readCell context.sizeCell
  let
    frame =
      seaFrame
        { timestamp
        , startedAt: context.startedAt
        , dragging: state.dragging
        , labHoverTarget: hover
        , canvasWidth: size.width
        , canvasHeight: size.height
        , dark
        }
        state
  Sensors.writeCell context.stateCell frame.state
  Fx.sync \_ -> drawSea context.handle frame.uniforms

startSeaLoop :: SeaContext -> Fx.Effect Fx.Never Fx.NoServices Unit
startSeaLoop context = do
  stopSeaLoop context
  cleanup <- Sensors.startLoop (seaTick context)
  Sensors.writeCell context.loopCell cleanup

stopSeaLoop :: SeaContext -> Fx.Effect Fx.Never Fx.NoServices Unit
stopSeaLoop context = Sensors.readCell context.loopCell >>= Sensors.runCleanup

seaTick :: SeaContext -> Number -> Fx.Effect Fx.Never Fx.NoServices Boolean
seaTick context timestamp =
  renderSeaAt context timestamp >>= \_ -> pure true
