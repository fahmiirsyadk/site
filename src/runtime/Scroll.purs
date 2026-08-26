module Runtime.Scroll where

import Prelude

import Data.Array as Array
import Data.Int as Int

type HeadingGeometry =
  { id :: String
  , level :: Int
  , top :: Number
  }

type Geometry =
  { scrollTop :: Number
  , scrollHeight :: Number
  , clientHeight :: Number
  , rootTop :: Number
  , headings :: Array HeadingGeometry
  }

type HeadingPosition =
  { id :: String
  , level :: Int
  , progress :: Int
  }

type ReadingProgress =
  { progress :: Int
  , headings :: Array HeadingPosition
  }

headingAnchorRatio :: Number
headingAnchorRatio = 0.35

headingOffset :: Number
headingOffset = 128.0

clampPercent :: Number -> Int
clampPercent value = Int.round (clamp 0.0 100.0 value)

scrollRange :: Geometry -> Number
scrollRange geometry = max 0.0 (geometry.scrollHeight - geometry.clientHeight)

readingProgress :: Geometry -> ReadingProgress
readingProgress geometry =
  let range = scrollRange geometry
      markerLine = geometry.clientHeight * headingAnchorRatio
      positionOf heading =
        let offset = geometry.scrollTop + heading.top - geometry.rootTop
        in { id: heading.id
           , level: heading.level
           , progress: if range == 0.0 then 0 else clampPercent (((offset - markerLine) / range) * 100.0)
           }
  in { progress: if range == 0.0 then 0 else clampPercent ((geometry.scrollTop / range) * 100.0)
     , headings: map positionOf geometry.headings
     }

sameGeometry :: Geometry -> Geometry -> Boolean
sameGeometry left right =
  left.scrollTop == right.scrollTop
    && left.scrollHeight == right.scrollHeight
    && left.clientHeight == right.clientHeight
    && left.rootTop == right.rootTop
    && sameHeadings left.headings right.headings

sameHeadings :: Array HeadingGeometry -> Array HeadingGeometry -> Boolean
sameHeadings left right =
  Array.length left == Array.length right
    && Array.all identity (Array.zipWith sameHeading left right)

sameHeading :: HeadingGeometry -> HeadingGeometry -> Boolean
sameHeading left right =
  left.id == right.id && left.level == right.level && left.top == right.top

headingScrollTarget
  :: { scrollTop :: Number
     , rootTop :: Number
     , headingTop :: Number
     }
  -> Number
headingScrollTarget target =
  target.scrollTop + target.headingTop - target.rootTop - headingOffset

progressScrollTarget :: { range :: Number, percent :: Int } -> Number
progressScrollTarget target =
  target.range * (Int.toNumber (max 0 (min 100 target.percent)) / 100.0)
