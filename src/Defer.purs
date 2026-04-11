module Defer (runWhenIdle) where

import Prelude

import Effect (Effect)

-- | Run after the browser is idle (`requestIdleCallback`), or a short rAF+timeout
-- | fallback. Use for WebGL, heavy DOM measurement, and other non-critical work so
-- | hydration and first paint stay responsive.
foreign import runWhenIdle :: Effect Unit -> Effect Unit
