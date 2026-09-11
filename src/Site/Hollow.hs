-----------------------------------------------------------------------------
-- | The hollow mark's simulation, ported from the source's
-- @Runtime.HollowMotion@ and the pure half of @Platform.Browser.HollowMark@.
-- Frame timing is shared with the sea ('Site.Sea.frameTiming').
module Site.Hollow
  ( HollowMotion (..)
  , HollowVisual (..)
  , HollowFrame (..)
  , HollowState (..)
  , HollowPointerKind (..)
  , HollowPointerEvent (..)
  , HollowInput (..)
  , HollowUniforms (..)
  , initialHollowMotion
  , beginHollowDrag
  , dragHollow
  , endHollowDrag
  , stepHollowMotion
  , initialHollowVisual
  , stepHollowVisual
  , hollowCubeRotation
  , hollowDragValues
  , initialHollowState
  , hollowFrame
  , hollowPointer
  ) where
-----------------------------------------------------------------------------
import           Site.Sea (frameTiming, timingDuration, timingSeconds)
-----------------------------------------------------------------------------
-- | The angle machine: a smooth angle chases a target with angular velocity,
-- then snaps to the nearest full turn when the spin dies out.
data HollowMotion = HollowMotion
  { hmTargetAngle       :: Double
  , hmSmoothAngle       :: Double
  , hmAngularVelocity   :: Double
  , hmSnapAngle         :: Double
  , hmSnapping          :: Bool
  , hmInteractionActive :: Bool
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data HollowVisual = HollowVisual
  { hvLabHover :: Double
  , hvSeconds  :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data HollowFrame = HollowFrame
  { hfDragging      :: Bool
  , hfFrameDuration :: Double
  , hfReduceMotion  :: Bool
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data HollowState = HollowState
  { hsMotion            :: HollowMotion
  , hsVisual            :: HollowVisual
  , hsPreviousFrameTime :: Double
  , hsDragging          :: Bool
  , hsDragStartX        :: Double
  , hsDragStartAngle    :: Double
  , hsPreviousPointerX  :: Double
  , hsPreviousPointerTime :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data HollowPointerKind = HollowDown | HollowMove | HollowUp
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data HollowPointerEvent = HollowPointerEvent
  { hpKind  :: HollowPointerKind
  , hpX     :: Double
  , hpY     :: Double
  , hpNow   :: Double
  , hpWidth :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Everything a frame needs that is not in 'HollowState'.
data HollowInput = HollowInput
  { hiTimestamp      :: Double
  , hiStartedAt      :: Double
  , hiReduceMotion   :: Bool
  , hiLabHoverTarget :: Double
  , hiCanvasWidth    :: Int
  , hiCanvasHeight   :: Int
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data HollowUniforms = HollowUniforms
  { huAngle     :: Double
  , huCubeAngle :: Double
  , huAspect    :: Double
  , huTime      :: Double
  , huLabHover  :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
initialHollowMotion :: HollowMotion
initialHollowMotion = HollowMotion
  { hmTargetAngle = 0.0
  , hmSmoothAngle = 0.0
  , hmAngularVelocity = 0.0
  , hmSnapAngle = 0.0
  , hmSnapping = False
  , hmInteractionActive = False
  }
-----------------------------------------------------------------------------
beginHollowDrag :: HollowMotion -> HollowMotion
beginHollowDrag motion = motion
  { hmAngularVelocity = 0.0
  , hmSnapping = False
  , hmInteractionActive = True
  }
-----------------------------------------------------------------------------
dragHollow :: (Double, Double) -> HollowMotion -> HollowMotion
dragHollow (angle, velocity) motion = motion
  { hmTargetAngle = angle
  , hmAngularVelocity = velocity
  , hmSnapping = False
  , hmInteractionActive = True
  }
-----------------------------------------------------------------------------
endHollowDrag :: Bool -> HollowMotion -> HollowMotion
endHollowDrag stale motion = motion
  { hmAngularVelocity = if stale then 0.0 else hmAngularVelocity motion
  , hmInteractionActive = True
  }
-----------------------------------------------------------------------------
stepHollowMotion :: HollowFrame -> HollowMotion -> HollowMotion
stepHollowMotion frame motion
  | hfDragging frame && hfReduceMotion frame = motion { hmSmoothAngle = hmTargetAngle motion }
  | hfDragging frame = smoothHollow True (hfFrameDuration frame) motion
  | hfReduceMotion frame = initialHollowMotion
      { hmTargetAngle = nearestTurn (hmTargetAngle motion)
      , hmSmoothAngle = nearestTurn (hmTargetAngle motion)
      }
  | hmSnapping motion =
      let targetAngle = hmTargetAngle motion
            + (hmSnapAngle motion - hmTargetAngle motion)
            * min 1.0 (hfFrameDuration frame * 0.01)
          next = smoothHollow True (hfFrameDuration frame)
            motion { hmTargetAngle = targetAngle }
      in if abs (targetAngle - hmSnapAngle motion) < 0.0005
            && abs (hmSmoothAngle next - hmSnapAngle motion) < 0.0005
           then initialHollowMotion
           else next
  | otherwise =
      let targetAngle = hmTargetAngle motion
            + hmAngularVelocity motion * hfFrameDuration frame
          angularVelocity = hmAngularVelocity motion
            * (0.92 ** (hfFrameDuration frame / 16.67))
          shouldSnap = abs angularVelocity < 0.00025
          next = motion
            { hmTargetAngle = targetAngle
            , hmAngularVelocity = if shouldSnap then 0.0 else angularVelocity
            , hmSnapAngle =
                if shouldSnap then nearestTurn targetAngle else hmSnapAngle motion
            , hmSnapping = shouldSnap
            }
          smoothed = smoothHollow
            (shouldSnap || abs angularVelocity >= 0.00025)
            (hfFrameDuration frame)
            next
      in if shouldSnap
            && abs (targetAngle - hmSnapAngle smoothed) < 0.0005
            && abs (hmSmoothAngle smoothed - hmSnapAngle smoothed) < 0.0005
           then initialHollowMotion
           else smoothed
-----------------------------------------------------------------------------
smoothHollow :: Bool -> Double -> HollowMotion -> HollowMotion
smoothHollow interactionActive frameDuration motion = motion
  { hmSmoothAngle = hmSmoothAngle motion
      + (hmTargetAngle motion - hmSmoothAngle motion)
      * min 1.0 (frameDuration * 0.012)
  , hmInteractionActive = interactionActive
  }
-----------------------------------------------------------------------------
nearestTurn :: Double -> Double
nearestTurn angle = fromIntegral (round (angle / fullTurn) :: Int) * fullTurn
-----------------------------------------------------------------------------
fullTurn :: Double
fullTurn = pi * 2.0
-----------------------------------------------------------------------------
initialHollowVisual :: Double -> HollowVisual
initialHollowVisual labHover = HollowVisual
  { hvLabHover = labHover
  , hvSeconds = 0.0
  }
-----------------------------------------------------------------------------
stepHollowVisual
  :: Double
  -- ^ frame duration
  -> Double
  -- ^ lab hover target
  -> Bool
  -- ^ interaction active
  -> Bool
  -- ^ reduce motion
  -> HollowVisual
  -> HollowVisual
stepHollowVisual frameDuration labHoverTarget interactionActive reduceMotion visual =
  HollowVisual
    { hvLabHover = if reduceMotion then labHoverTarget else hvLabHover visual
        + (labHoverTarget - hvLabHover visual) * min 1.0 (frameDuration * 0.003)
    , hvSeconds =
        if interactionActive || reduceMotion
          then hvSeconds visual
          else hvSeconds visual + frameDuration / 1000.0
    }
-----------------------------------------------------------------------------
hollowCubeRotation :: Bool -> Double -> Double
hollowCubeRotation reduceMotion elapsed =
  if reduceMotion then 0.48 else elapsed * 0.9
-----------------------------------------------------------------------------
hollowDragValues
  :: Double -> Double -> Double -> Double -> Double -> Double
  -> (Double, Double)
hollowDragValues dragStartAngle dragStartX currentX previousX width elapsed =
  ( dragStartAngle + (currentX - dragStartX) / safeWidth * turn
  , ((currentX - previousX) / safeWidth * turn) / safeElapsed
  )
  where
    safeWidth = max width 1.0
    safeElapsed = max elapsed 1.0
    turn = pi * 2.0
-----------------------------------------------------------------------------
initialHollowState :: Double -> HollowState
initialHollowState startedAt = HollowState
  { hsMotion = initialHollowMotion
  , hsVisual = initialHollowVisual 0.0
  , hsPreviousFrameTime = startedAt
  , hsDragging = False
  , hsDragStartX = 0.0
  , hsDragStartAngle = 0.0
  , hsPreviousPointerX = 0.0
  , hsPreviousPointerTime = 0.0
  }
-----------------------------------------------------------------------------
-- | One frame of the mount: steps the two machines and derives the uniforms.
hollowFrame :: HollowInput -> HollowState -> (HollowState, HollowUniforms)
hollowFrame input state = (stepped, uniforms)
  where
    timing = frameTiming
      (hiTimestamp input)
      (hsPreviousFrameTime state)
      (hiStartedAt input)
    motion = stepHollowMotion
      (HollowFrame
         { hfDragging = hsDragging state
        , hfFrameDuration = timingDuration timing
        , hfReduceMotion = hiReduceMotion input
        })
      (hsMotion state)
    visual = stepHollowVisual
      (timingDuration timing)
      (hiLabHoverTarget input)
      (hmInteractionActive motion)
      (hiReduceMotion input)
      (hsVisual state)
    cubeRotation = hollowCubeRotation (hiReduceMotion input) (timingSeconds timing)
    stepped = state
      { hsMotion = motion
      , hsVisual = visual
      , hsPreviousFrameTime = hiTimestamp input
      }
    uniforms = HollowUniforms
      { huAngle = hmSmoothAngle motion
      , huCubeAngle = cubeRotation
      , huAspect = fromIntegral (hiCanvasWidth input) / fromIntegral (hiCanvasHeight input)
      , huTime = if hiReduceMotion input then 0.0 else hvSeconds visual
      , huLabHover = hvLabHover visual
      }
-----------------------------------------------------------------------------
hollowPointer :: HollowPointerEvent -> HollowState -> HollowState
hollowPointer event state = case hpKind event of
  HollowDown -> state
    { hsMotion = beginHollowDrag (hsMotion state)
    , hsDragging = True
    , hsDragStartX = hpX event
    , hsDragStartAngle = hmTargetAngle (hsMotion state)
    , hsPreviousPointerX = hpX event
    , hsPreviousPointerTime = hpNow event
    }
  HollowMove
    | hsDragging state ->
        let drag = hollowDragValues
              (hsDragStartAngle state)
              (hsDragStartX state)
              (hpX event)
              (hsPreviousPointerX state)
              (hpWidth event)
              (hpNow event - hsPreviousPointerTime state)
        in state
          { hsMotion = dragHollow drag (hsMotion state)
          , hsPreviousPointerX = hpX event
          , hsPreviousPointerTime = hpNow event
          }
    | otherwise -> state
  HollowUp -> state
    { hsMotion = endHollowDrag
        (hpNow event - hsPreviousPointerTime state > 80.0)
        (hsMotion state)
    , hsDragging = False
    }
