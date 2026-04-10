module RelativeTime (relativeTimeLabel, hydrationSafeDateLabel, postDateLabel) where

import Prelude

-- | See https://pursuit.purescript.org/packages/purescript-datetime/6.1.0/docs/Data.DateTime#v:date
import Data.DateTime (Date, date, day, month, year)
import Data.DateTime.Instant (Instant, diff, instant, toDateTime)
import Data.Enum (fromEnum)
import Data.Int (round)
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.Time.Duration (Milliseconds(..))
import Effect (Effect)
import Effect.Now (now)
import Effect.Ref as Ref
import Effect.Unsafe (unsafePerformEffect)
import IsoInstant (parseIsoToMillis)
import JS.Intl.Options.Numeric as Numeric
import JS.Intl.Options.RelativeTimeUnit as RTU
import JS.Intl.Options.Style as Style
import JS.Intl.RelativeTimeFormat as RTF

millisToInstant :: String -> Maybe Instant
millisToInstant s =
  let
    n = parseIsoToMillis s
  in
    if n < 0.0 then Nothing else instant (Milliseconds n)

-- | Luna VDOM: use `false` for first paint (matches SSR HTML), then `true` after hydration
-- | so `relativeTimeLabel` runs only on the client and avoids mismatch.
postDateLabel :: Boolean -> String -> String
postDateLabel useRelative iso =
  if useRelative then relativeTimeLabel iso else hydrationSafeDateLabel iso

-- | Calendar date only — deterministic for prerender + browser hydration (no "now").
hydrationSafeDateLabel :: String -> String
hydrationSafeDateLabel isoStr =
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

-- | Human-readable relative time from an ISO-8601 date string.
-- | Uses `Intl.RelativeTimeFormat` (via `js-intl`) for locale-aware phrasing.
relativeTimeLabel :: String -> String
relativeTimeLabel isoStr =
  unsafePerformEffect do
    case millisToInstant isoStr of
      Nothing -> pure isoStr
      Just postI -> do
        nowI <- now
        let
          d :: Milliseconds
          d = diff nowI postI
        rtf <- cachedRelativeTimeFormat
        pure $ formatIntlAgo rtf d

-- | One shared formatter: default locale, short style, numeric "auto".
cachedRelativeTimeFormat :: Effect RTF.RelativeTimeFormat
cachedRelativeTimeFormat = do
  mb <- Ref.read relativeTimeFormatRef
  case mb of
    Just r -> pure r
    Nothing -> do
      r <-
        RTF.new []
          { numeric: Numeric.Auto
          , style: Style.Short
          }
      Ref.write (Just r) relativeTimeFormatRef
      pure r

relativeTimeFormatRef :: Ref.Ref (Maybe RTF.RelativeTimeFormat)
relativeTimeFormatRef =
  unsafePerformEffect (Ref.new Nothing)

-- Thresholds in milliseconds (kept the same sensible ladder you had)
minuteMs :: Number
minuteMs = 60000.0

hourMs :: Number
hourMs = 3600000.0

dayMs :: Number
dayMs = 86400000.0

weekMs :: Number
weekMs = 604800000.0

monthMs :: Number
monthMs = 2592000000.0

yearMs :: Number
yearMs = 31536000000.0

-- | Past times use negative values per ECMA-402.
formatIntlAgo :: RTF.RelativeTimeFormat -> Milliseconds -> String
formatIntlAgo rtf (Milliseconds msRaw) =
  if msRaw < 0.0 then
    "soon"
  else if msRaw < minuteMs then
    "just now"
  else
    let
      ago :: Int -> RTU.RelativeTimeUnit -> String
      ago n u = RTF.format rtf (negate n) u
    in
      if msRaw < hourMs then
        ago (round (msRaw / minuteMs)) RTU.Minutes
      else if msRaw < dayMs then
        ago (round (msRaw / hourMs)) RTU.Hours
      else if msRaw < weekMs then
        ago (round (msRaw / dayMs)) RTU.Days
      else if msRaw < monthMs then
        ago (round (msRaw / weekMs)) RTU.Weeks
      else if msRaw < yearMs then
        ago (round (msRaw / monthMs)) RTU.Months
      else
        ago (round (msRaw / yearMs)) RTU.Years