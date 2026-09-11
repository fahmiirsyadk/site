-----------------------------------------------------------------------------
-- | The sea footer's simulation, ported from the source site's
-- @Runtime.Frame@, @Runtime.SeaMotion@, @Runtime.SeaRender@ and the pure half
-- of @Platform.Browser.Sea@.
--
-- Everything here is pure so the native tests can drive it. The effects that
-- feed it -- the animation loop, pointer input, resize -- live in
-- 'Site.Widgets.Sea'.
--
-- Record fields are prefixed per type. Several shapes carry the same idea
-- (motion velocities, the input's drag flag) and GHC does not allow two
-- selectors to share a name in one module.
module Site.Sea
  ( -- * Frame timing
    FrameTiming (..)
  , frameTiming
    -- * Motion
  , SeaMotion (..)
  , SeaFrame (..)
  , initialSeaMotion
  , seaDragTarget
  , retargetSeaMotion
  , stepSeaMotion
    -- * Layout
  , RenderLayout (..)
  , renderLayoutFor
    -- * State and uniforms
  , SeaPointerKind (..)
  , SeaPointerEvent (..)
  , SeaState (..)
  , SeaUniforms (..)
  , SeaInput (..)
  , initialSeaState
  , seaPointer
  , seaFrame
  ) where
-----------------------------------------------------------------------------
-- | Seconds since the mount, the clamped inter-frame duration, and the
-- two-second intro ramp. The duration clamp keeps a backgrounded tab from
-- snapping the motion when it returns.
data FrameTiming = FrameTiming
  { timingSeconds  :: Double
  , timingDuration :: Double
  , timingIntro    :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
frameTiming :: Double -> Double -> Double -> FrameTiming
frameTiming timestamp previousTimestamp startedAt = FrameTiming
  { timingSeconds = seconds
  , timingDuration = min (timestamp - previousTimestamp) 40.0
  , timingIntro = min 1.0 (seconds / 2.0)
  }
  where
    seconds = (timestamp - startedAt) / 1000.0
-----------------------------------------------------------------------------
-- | The cube's motion, matching the source's @SeaMotion@ exactly. The
-- @smooth@ values chase @target@, velocities are a damped derivative of that
-- chase, and @motionLabHover@ eases toward its target.
data SeaMotion = SeaMotion
  { motionTargetX   :: Double
  , motionTargetY   :: Double
  , motionSmoothX   :: Double
  , motionSmoothY   :: Double
  , motionPreviousX :: Double
  , motionPreviousY :: Double
  , motionVelocityX :: Double
  , motionVelocityY :: Double
  , motionLabHover  :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
initialSeaMotion :: SeaMotion
initialSeaMotion = SeaMotion
  { motionTargetX = 0.0
  , motionTargetY = 0.0
  , motionSmoothX = 0.0
  , motionSmoothY = 0.0
  , motionPreviousX = 0.0
  , motionPreviousY = 0.0
  , motionVelocityX = 0.0
  , motionVelocityY = 0.0
  , motionLabHover = 0.0
  }
-----------------------------------------------------------------------------
-- | What one frame of stepping needs.
data SeaFrame = SeaFrame
  { frameDragging       :: Bool
  , frameDuration       :: Double
  , frameLabHoverTarget :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Where a drag puts the cube: the pointer delta scaled by the element's
-- size so the gesture feels the same at any footer width.
seaDragTarget
  :: Double
  -- ^ base x
  -> Double
  -- ^ base y
  -> Double
  -- ^ start x
  -> Double
  -- ^ start y
  -> Double
  -- ^ current x
  -> Double
  -- ^ current y
  -> Double
  -- ^ element width
  -> Double
  -- ^ element height
  -> (Double, Double)
seaDragTarget baseX baseY startX startY currentX currentY width height =
  ( baseX + (currentX - startX) / max 1.0 width * 10.0
  , baseY - (currentY - startY) / max 1.0 height * 8.0
  )
-----------------------------------------------------------------------------
-- | Clamp a drag target to the sea's bounds.
retargetSeaMotion :: (Double, Double) -> SeaMotion -> SeaMotion
retargetSeaMotion (x, y) motion = motion
  { motionTargetX = clampValue (-7.0) 7.0 x
  , motionTargetY = clampValue 0.0 11.0 y
  }
-----------------------------------------------------------------------------
stepSeaMotion :: SeaFrame -> SeaMotion -> SeaMotion
stepSeaMotion frame motion = motion
  { motionSmoothX = smoothX
  , motionSmoothY = smoothY
  , motionPreviousX = smoothX
  , motionPreviousY = smoothY
  , motionVelocityX = velocityX * damping
  , motionVelocityY = velocityY * damping
  , motionLabHover = motionLabHover motion
      + (frameLabHoverTarget frame - motionLabHover motion)
      * min 1.0 (frameDuration frame * 0.003)
  }
  where
    smoothX = motionSmoothX motion
      + (motionTargetX motion - motionSmoothX motion) * 0.05
    smoothY = motionSmoothY motion
      + (motionTargetY motion - motionSmoothY motion) * 0.05
    deltaX = smoothX - motionPreviousX motion
    deltaY = smoothY - motionPreviousY motion
    velocityX = motionVelocityX motion
      + (deltaX * 60.0 - motionVelocityX motion) * 0.06
    velocityY = motionVelocityY motion
      + (deltaY * 60.0 - motionVelocityY motion) * 0.06
    damping = if frameDragging frame then 1.0 else 0.95
-----------------------------------------------------------------------------
clampValue :: Double -> Double -> Double -> Double
clampValue lower upper value = max lower (min upper value)
-----------------------------------------------------------------------------
-- | The canvas is backed at the CSS size times a capped device pixel ratio;
-- the scene renders into an offscreen buffer that shrinks with area, so a
-- large footer does not pay for full-resolution water. Both clamps come from
-- the source's @renderLayout@.
data RenderLayout = RenderLayout
  { canvasWidth  :: Int
  , canvasHeight :: Int
  , pixelRatio   :: Double
  , sceneWidth   :: Int
  , sceneHeight  :: Int
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
renderLayoutFor :: Double -> Double -> Double -> RenderLayout
renderLayoutFor width height devicePixelRatio = RenderLayout
  { canvasWidth = max 1 (round (width * ratio))
  , canvasHeight = max 1 (round (height * ratio))
  , pixelRatio = ratio
  , sceneWidth = max 1 (floor (width * sceneRatio))
  , sceneHeight = max 1 (floor (height * sceneRatio))
  }
  where
    area = max 1.0 (width * height)
    ratio = min 1.5 (max 1.0 devicePixelRatio)
    sceneRatio = min 0.85 (sqrt (220000.0 / area))
-----------------------------------------------------------------------------
-- | Pointer transitions. Cancel is mapped to 'PointerUp' by the runtime, the
-- same way the source's observer does.
data SeaPointerKind = PointerDown | PointerMove | PointerUp
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data SeaPointerEvent = SeaPointerEvent
  { pointerKind   :: SeaPointerKind
  , pointerX      :: Double
  , pointerY      :: Double
  , pointerWidth  :: Double
  , pointerHeight :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | The live simulation state. The uniforms are derived from it every frame.
data SeaState = SeaState
  { motion            :: SeaMotion
  , previousFrameTime :: Double
  , stateDragging     :: Bool
  , stateStartX       :: Double
  , stateStartY       :: Double
  , stateBaseX        :: Double
  , stateBaseY        :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
initialSeaState :: Double -> Double -> SeaState
initialSeaState startedAt labHover = SeaState
  { motion = initialSeaMotion { motionLabHover = labHover }
  , previousFrameTime = startedAt
  , stateDragging = False
  , stateStartX = 0.0
  , stateStartY = 0.0
  , stateBaseX = 0.0
  , stateBaseY = 0.0
  }
-----------------------------------------------------------------------------
seaPointer :: SeaPointerEvent -> SeaState -> SeaState
seaPointer event state = case pointerKind event of
  PointerDown -> state
    { stateDragging = True
    , stateStartX = pointerX event
    , stateStartY = pointerY event
    , stateBaseX = motionTargetX (motion state)
    , stateBaseY = motionTargetY (motion state)
    }
  PointerMove
    | stateDragging state ->
        state
          { motion = retargetSeaMotion
              (seaDragTarget
                (stateBaseX state)
                (stateBaseY state)
                (stateStartX state)
                (stateStartY state)
                (pointerX event)
                (pointerY event)
                (pointerWidth event)
                (pointerHeight event))
              (motion state)
          }
    | otherwise -> state
  PointerUp -> state { stateDragging = False }
-----------------------------------------------------------------------------
-- | The resolved uniform values for one frame.
data SeaUniforms = SeaUniforms
  { time        :: Double
  , resolutionX :: Double
  , resolutionY :: Double
  , cubeX       :: Double
  , cubeY       :: Double
  , velocityX   :: Double
  , velocityY   :: Double
  , uiDark      :: Double
  , intro       :: Double
  , labHover    :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Everything a frame needs that is not in 'SeaState'.
data SeaInput = SeaInput
  { inputTimestamp      :: Double
  , inputStartedAt      :: Double
  , inputLabHoverTarget :: Double
  , inputCanvasWidth    :: Int
  , inputCanvasHeight   :: Int
  , inputDark           :: Bool
  , inputReducedMotion  :: Bool
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | One frame of the mount, matching the original render loop's math.
--
-- Reduced motion freezes time and the cube but still reports the theme and
-- hover, so a preference change redraws rather than animates.
seaFrame :: SeaInput -> SeaState -> (SeaState, SeaUniforms)
seaFrame input state = (stepped, uniforms)
  where
    timing = frameTiming (inputTimestamp input) (previousFrameTime state) (inputStartedAt input)
    stepped = state
      { motion = motion'
      , previousFrameTime = inputTimestamp input
      }
    motion' = stepSeaMotion
      (SeaFrame
         { frameDragging = stateDragging state
        , frameDuration = timingDuration timing
        , frameLabHoverTarget = inputLabHoverTarget input
        })
      (motion state)
    reduced = inputReducedMotion input
    uniforms = SeaUniforms
      { time = if reduced then 0.0 else timingSeconds timing
      , resolutionX = fromIntegral (inputCanvasWidth input)
      , resolutionY = fromIntegral (inputCanvasHeight input) * 1.92
      , cubeX = if reduced then motionTargetX motion' else motionSmoothX motion'
      , cubeY = if reduced then motionTargetY motion' else motionSmoothY motion'
      , velocityX = if reduced then 0.0 else motionVelocityX motion'
      , velocityY = if reduced then 0.0 else motionVelocityY motion'
      , uiDark = if inputDark input then 1.0 else 0.0
      , intro = if reduced then 1.0 else timingIntro timing
      , labHover = if reduced then inputLabHoverTarget input else motionLabHover motion'
      }
