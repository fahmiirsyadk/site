module Runtime.Frame where

import Prelude

type FrameTiming =
  { seconds :: Number
  , frameDuration :: Number
  , intro :: Number
  }

frameTiming :: { timestamp :: Number, previousTimestamp :: Number, startedAt :: Number } -> FrameTiming
frameTiming input =
  let seconds = (input.timestamp - input.startedAt) / 1000.0
  in
    { seconds
    , frameDuration: min (input.timestamp - input.previousTimestamp) 40.0
    , intro: min 1.0 (seconds / 2.0)
    }
