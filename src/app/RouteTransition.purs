module App.RouteTransition where

data RouteMotion
  = Idle
  | Leaving
  | Entering

toString :: RouteMotion -> String
toString motion = case motion of
  Idle -> "idle"
  Leaving -> "leaving"
  Entering -> "entering"
