module RelativeTime (postDateLabel) where

import Prelude

import Data.DateTime (Date, date, day, month, year)
import Data.DateTime.Instant (Instant, instant, toDateTime)
import Data.Enum (fromEnum)
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.Time.Duration (Milliseconds(..))
import IsoInstant (parseIsoToMillis)

millisToInstant :: String -> Maybe Instant
millisToInstant s =
  let
    n = parseIsoToMillis s
  in
    if n < 0.0 then Nothing else instant (Milliseconds n)

-- | Calendar date only — deterministic for prerender + browser hydration (no "now").
-- | Client-side relative-time display is patched separately by JS after hydration.
postDateLabel :: String -> String
postDateLabel isoStr =
  case millisToInstant isoStr of
    Nothing -> isoStr
    Just postI ->
      let
        d :: Date
        d = date (toDateTime postI)
        y = fromEnum (year d)
        -- `Show Month` is full English names → first 3 chars = usual abbreviations
        mon = String.take 3 (show (month d))
        dd = fromEnum (day d)
      in
        show dd <> " " <> mon <> " " <> show y
