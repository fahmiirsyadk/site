module RelativeTime (relativeTimeLabel) where

import Prelude

import Data.DateTime.Instant (Instant, diff, instant)
import Data.Int (round)
import Data.Maybe (Maybe(..))
import Data.Time.Duration (Milliseconds(..))
import Effect.Now (now)
import Effect.Unsafe (unsafePerformEffect)
import IsoInstant (parseIsoToMillis)

millisToInstant :: String -> Maybe Instant
millisToInstant s =
  let
    n = parseIsoToMillis s
  in
    if n < 0.0 then Nothing else instant (Milliseconds n)

-- | Human-readable relative time from an ISO-8601 date string (e.g. post `date` field).
relativeTimeLabel :: String -> String
relativeTimeLabel isoStr =
  unsafePerformEffect do
    nowI <- now
    case millisToInstant isoStr of
      Nothing -> pure isoStr
      Just postI -> do
        let
          d :: Milliseconds
          d = diff nowI postI
        pure case d of
          Milliseconds n -> formatAgo n

formatAgo :: Number -> String
formatAgo msRaw =
  let
    ms = if msRaw < 0.0 then 0.0 - msRaw else msRaw
  in
    if msRaw < 0.0 then
      "soon"
    else if ms < 60000.0 then
      "just now"
    else if ms < 3600000.0 then
      show (round (ms / 60000.0)) <> "min ago"
    else if ms < 86400000.0 then
      show (round (ms / 3600000.0)) <> "h ago"
    else if ms < 604800000.0 then
      show (round (ms / 86400000.0)) <> "d ago"
    else if ms < 2592000000.0 then
      show (round (ms / 604800000.0)) <> "wk ago"
    else if ms < 31536000000.0 then
      show (round (ms / 2592000000.0)) <> "mo ago"
    else
      show (round (ms / 31536000000.0)) <> "y ago"
