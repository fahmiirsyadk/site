module Runtime.HollowMotion where

import Prelude

import Data.Number as Number

type HollowMotion =
  { targetAngle :: Number
  , smoothAngle :: Number
  , angularVelocity :: Number
  , snapAngle :: Number
  , snapping :: Boolean
  , interactionActive :: Boolean
  }

type HollowFrame =
  { dragging :: Boolean
  , frameDuration :: Number
  , reduceMotion :: Boolean
  }

type HollowVisual =
  { labHover :: Number
  , motionSeconds :: Number
  }

initialHollowVisual :: Number -> HollowVisual
initialHollowVisual labHover =
  { labHover
  , motionSeconds: 0.0
  }

hollowDragValues ::
  { dragStartAngle :: Number
  , dragStartX :: Number
  , currentX :: Number
  , previousX :: Number
  , width :: Number
  , elapsed :: Number
  } -> { angle :: Number, velocity :: Number }
hollowDragValues input =
  let
    width = max input.width 1.0
    elapsed = max input.elapsed 1.0
    turn = Number.pi * 2.0
  in
    { angle: input.dragStartAngle + (input.currentX - input.dragStartX) / width * turn
    , velocity: ((input.currentX - input.previousX) / width * turn) / elapsed
    }

stepHollowVisual ::
  { frameDuration :: Number
  , labHoverTarget :: Number
  , interactionActive :: Boolean
  , reduceMotion :: Boolean
  } -> HollowVisual -> HollowVisual
stepHollowVisual frame visual =
  { labHover: visual.labHover
      + (frame.labHoverTarget - visual.labHover)
      * min 1.0 (frame.frameDuration * 0.003)
  , motionSeconds: if frame.interactionActive || frame.reduceMotion then
      visual.motionSeconds
    else
      visual.motionSeconds + frame.frameDuration / 1000.0
  }

hollowCubeRotation :: { elapsed :: Number, reduceMotion :: Boolean } -> Number
hollowCubeRotation input = if input.reduceMotion then 0.48 else input.elapsed * 0.9

initialHollowMotion :: HollowMotion
initialHollowMotion =
  { targetAngle: 0.0
  , smoothAngle: 0.0
  , angularVelocity: 0.0
  , snapAngle: 0.0
  , snapping: false
  , interactionActive: false
  }

beginHollowDrag :: HollowMotion -> HollowMotion
beginHollowDrag motion = motion
  { angularVelocity = 0.0
  , snapping = false
  , interactionActive = true
  }

dragHollow :: { angle :: Number, velocity :: Number } -> HollowMotion -> HollowMotion
dragHollow input motion = motion
  { targetAngle = input.angle
  , angularVelocity = input.velocity
  , snapping = false
  , interactionActive = true
  }

endHollowDrag :: { stale :: Boolean } -> HollowMotion -> HollowMotion
endHollowDrag input motion = motion
  { angularVelocity = if input.stale then 0.0 else motion.angularVelocity
  , interactionActive = true
  }

stepHollowMotion :: HollowFrame -> HollowMotion -> HollowMotion
stepHollowMotion frame motion
  | frame.dragging = smoothHollow true frame.frameDuration motion
  | frame.reduceMotion = initialHollowMotion
      { targetAngle = nearestTurn motion.targetAngle
      , smoothAngle = nearestTurn motion.targetAngle
      }
  | motion.snapping =
      let targetAngle = motion.targetAngle
            + (motion.snapAngle - motion.targetAngle) * min 1.0 (frame.frameDuration * 0.01)
          next = smoothHollow true frame.frameDuration (motion { targetAngle = targetAngle })
      in if Number.abs (targetAngle - motion.snapAngle) < 0.0005
          && Number.abs (next.smoothAngle - motion.snapAngle) < 0.0005 then
          initialHollowMotion
        else
          next
  | otherwise =
      let targetAngle = motion.targetAngle + motion.angularVelocity * frame.frameDuration
          angularVelocity = motion.angularVelocity * Number.pow 0.92 (frame.frameDuration / 16.67)
          shouldSnap = Number.abs angularVelocity < 0.00025
          next = motion
            { targetAngle = targetAngle
            , angularVelocity = if shouldSnap then 0.0 else angularVelocity
            , snapAngle = if shouldSnap then nearestTurn targetAngle else motion.snapAngle
            , snapping = shouldSnap
            }
          smoothed = smoothHollow (shouldSnap || Number.abs angularVelocity >= 0.00025) frame.frameDuration next
      in if shouldSnap
          && Number.abs (targetAngle - smoothed.snapAngle) < 0.0005
          && Number.abs (smoothed.smoothAngle - smoothed.snapAngle) < 0.0005 then
          initialHollowMotion
        else
          smoothed

smoothHollow :: Boolean -> Number -> HollowMotion -> HollowMotion
smoothHollow interactionActive frameDuration motion = motion
  { smoothAngle = motion.smoothAngle
      + (motion.targetAngle - motion.smoothAngle) * min 1.0 (frameDuration * 0.012)
  , interactionActive = interactionActive
  }

nearestTurn :: Number -> Number
nearestTurn angle = Number.round (angle / fullTurn) * fullTurn

fullTurn :: Number
fullTurn = Number.pi * 2.0
