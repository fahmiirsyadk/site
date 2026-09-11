-----------------------------------------------------------------------------
-- | The reading rail's math, ported from the source's @Runtime.Scroll@.
--
-- Pure: it turns a measured geometry into percentages. The DOM measurement
-- lives in 'Site.Widgets.Scroll'.
module Site.Scroll
  ( HeadingGeometry (..)
  , Geometry (..)
  , HeadingPosition (..)
  , ReadingProgress (..)
  , emptyReadingProgress
  , headingAnchorRatio
  , headingOffset
  , clampPercent
  , clampProgress
  , readingProgress
  , progressScrollTarget
  , headingScrollTarget
  ) where
-----------------------------------------------------------------------------
-- | One heading as measured: where it sits right now.
data HeadingGeometry = HeadingGeometry
  { geomId    :: String
  , geomLevel :: Int
  , geomTop   :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data Geometry = Geometry
  { geometryScrollTop    :: Double
  , geometryScrollHeight :: Double
  , geometryClientHeight :: Double
  , geometryRootTop      :: Double
  , geometryHeadings     :: [HeadingGeometry]
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | One heading as shown on the rail: the tick percentage it lights up.
data HeadingPosition = HeadingPosition
  { posId       :: String
  , posLevel    :: Int
  , posProgress :: Int
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data ReadingProgress = ReadingProgress
  { readingPercent  :: Int
  , readingHeadings :: [HeadingPosition]
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
emptyReadingProgress :: ReadingProgress
emptyReadingProgress = ReadingProgress
  { readingPercent = 0
  , readingHeadings = []
  }
-----------------------------------------------------------------------------
-- | A heading counts as "read" once it crosses 35% of the viewport, and its
-- tick aims 128px above that line so the marker sits where the heading will
-- be after the browser's scroll offset.
headingAnchorRatio :: Double
headingAnchorRatio = 0.35
-----------------------------------------------------------------------------
headingOffset :: Double
headingOffset = 128.0
-----------------------------------------------------------------------------
-- | JS @Math.round@ behaviour: halves round up. Haskell's 'round' is
-- banker's rounding, so it is not used.
clampPercent :: Double -> Int
clampPercent value = floor (max 0.0 (min 100.0 value) + 0.5)
-----------------------------------------------------------------------------
clampProgress :: Int -> Int
clampProgress = max 0 . min 100
-----------------------------------------------------------------------------
readingProgress :: Geometry -> ReadingProgress
readingProgress geometry = ReadingProgress
  { readingPercent = percentage (geometryScrollTop geometry)
  , readingHeadings = map positionOf (geometryHeadings geometry)
  }
  where
    range = max 0.0 (geometryScrollHeight geometry - geometryClientHeight geometry)
    markerLine = geometryClientHeight geometry * headingAnchorRatio
    percentage offset
      | range == 0.0 = 0
      | otherwise = clampPercent ((offset / range) * 100.0)
    positionOf heading = HeadingPosition
      { posId = geomId heading
      , posLevel = geomLevel heading
      , posProgress =
          if range == 0.0
            then 0
            else clampPercent
              ( ( ( geometryScrollTop geometry
                    + geomTop heading
                    - geometryRootTop geometry
                    - markerLine
                  )
                  / range
                )
                  * 100.0
              )
      }
-----------------------------------------------------------------------------
-- | Where the container should scroll to land on a percentage.
progressScrollTarget :: Double -> Int -> Double
progressScrollTarget range percent =
  range * (fromIntegral (clampProgress percent) / 100.0)
-----------------------------------------------------------------------------
-- | Where the container should scroll so a heading sits below the anchor.
headingScrollTarget :: Double -> Double -> Double -> Double
headingScrollTarget scrollTop rootTop headingTop =
  scrollTop + headingTop - rootTop - headingOffset
