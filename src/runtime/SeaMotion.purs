module Runtime.SeaMotion where

import Prelude

type SeaMotion =
  { targetX :: Number
  , targetY :: Number
  , smoothX :: Number
  , smoothY :: Number
  , previousX :: Number
  , previousY :: Number
  , velocityX :: Number
  , velocityY :: Number
  , labHover :: Number
  }

type SeaFrame =
  { dragging :: Boolean
  , frameDuration :: Number
  , labHoverTarget :: Number
  }

initialSeaMotion :: SeaMotion
initialSeaMotion =
  { targetX: 0.0
  , targetY: 0.0
  , smoothX: 0.0
  , smoothY: 0.0
  , previousX: 0.0
  , previousY: 0.0
  , velocityX: 0.0
  , velocityY: 0.0
  , labHover: 0.0
  }

seaDragTarget ::
  { baseX :: Number
  , baseY :: Number
  , startX :: Number
  , startY :: Number
  , currentX :: Number
  , currentY :: Number
  , width :: Number
  , height :: Number
  } -> { x :: Number, y :: Number }
seaDragTarget input =
  { x: input.baseX + (input.currentX - input.startX) / max 1.0 input.width * 10.0
  , y: input.baseY - (input.currentY - input.startY) / max 1.0 input.height * 8.0
  }

retargetSeaMotion :: { x :: Number, y :: Number } -> SeaMotion -> SeaMotion
retargetSeaMotion target motion = motion
  { targetX = clampValue (-7.0) 7.0 target.x
  , targetY = clampValue 0.0 11.0 target.y
  }

stepSeaMotion :: SeaFrame -> SeaMotion -> SeaMotion
stepSeaMotion frame motion =
  let smoothX = motion.smoothX + (motion.targetX - motion.smoothX) * 0.05
      smoothY = motion.smoothY + (motion.targetY - motion.smoothY) * 0.05
      deltaX = smoothX - motion.previousX
      deltaY = smoothY - motion.previousY
      velocityX = motion.velocityX + (deltaX * 60.0 - motion.velocityX) * 0.06
      velocityY = motion.velocityY + (deltaY * 60.0 - motion.velocityY) * 0.06
      damping = if frame.dragging then 1.0 else 0.95
  in motion
    { smoothX = smoothX
    , smoothY = smoothY
    , previousX = smoothX
    , previousY = smoothY
    , velocityX = velocityX * damping
    , velocityY = velocityY * damping
    , labHover = motion.labHover
        + (frame.labHoverTarget - motion.labHover)
        * min 1.0 (frame.frameDuration * 0.003)
    }

clampValue :: Number -> Number -> Number -> Number
clampValue lower upper value = max lower (min upper value)
