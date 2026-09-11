-----------------------------------------------------------------------------
-- | Canvas backing-store sizing, ported from the source's @Runtime.Canvas@.
-- The hollow mark backs at the device pixel ratio clamped to
-- 1..6, which keeps the 16px header mark crisp on high-density screens.
module Site.Canvas
  ( RasterLayout (..)
  , rasterLayout
  ) where
-----------------------------------------------------------------------------
data RasterLayout = RasterLayout
  { rasterCanvasWidth  :: Int
  , rasterCanvasHeight :: Int
  , rasterCssWidth     :: Int
  , rasterCssHeight    :: Int
  , rasterPixelRatio   :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
rasterLayout
  :: Double
  -- ^ css width
  -> Double
  -- ^ css height
  -> Double
  -- ^ device pixel ratio
  -> Double
  -- ^ minimum pixel ratio
  -> Double
  -- ^ maximum pixel ratio
  -> RasterLayout
rasterLayout width height deviceRatio minimumRatio maximumRatio = RasterLayout
  { rasterCanvasWidth = max 1 (round (width * ratio))
  , rasterCanvasHeight = max 1 (round (height * ratio))
  , rasterCssWidth = round width
  , rasterCssHeight = round height
  , rasterPixelRatio = ratio
  }
  where
    ratio = min maximumRatio (max minimumRatio deviceRatio)
