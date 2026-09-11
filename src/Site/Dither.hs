-----------------------------------------------------------------------------
-- | The dithered image's pure half, ported from the source's @Runtime.Dither@.
--
-- The ink color is parsed from the @--dither-ink@ custom property; the canvas
-- layout scales the source into the raster box and computes the texture
-- coordinates that crop it, center-out, on the axis that does not match. The
-- draw gate is the source's ~20fps limit: the loop keeps scheduling, the
-- frame is only re-rendered when 50ms have passed (or always, without the
-- loop, under reduced motion).
--
-- Everything here is pure so the native tests can drive it. The effects --
-- the context, the loop, the observers -- live in 'Site.Widgets.Dither'.
module Site.Dither
  ( -- * Ink
    Rgb (..)
  , ditherColor
  , parseColor
  , fallbackColor
    -- * Layout
  , DitherLayoutInput (..)
  , DitherLayout (..)
  , ditherLayout
    -- * Drawing
  , shouldDrawFrame
  , quadVertices
  , bayerMatrix
  ) where
-----------------------------------------------------------------------------
import           Data.Bits ((.&.), shiftR)
import           Data.Char (digitToInt, isHexDigit, isSpace)
import           Data.List (dropWhileEnd)
import           Miso.String (MisoString, fromMisoString)
-----------------------------------------------------------------------------
import           Site.Canvas (RasterLayout (..), rasterLayout)
-----------------------------------------------------------------------------
-- | The ink color, channels normalized to 0..1 as the shader wants them.
data Rgb = Rgb
  { rgbRed   :: Double
  , rgbGreen :: Double
  , rgbBlue  :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | The raster box and its source, in CSS pixels.
data DitherLayoutInput = DitherLayoutInput
  { dliWidth            :: Double
  , dliHeight           :: Double
  , dliDevicePixelRatio :: Double
  , dliSourceWidth      :: Double
  , dliSourceHeight     :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data DitherLayout = DitherLayout
  { dlCanvasWidth        :: Int
  , dlCanvasHeight       :: Int
  , dlCssWidth           :: Int
  , dlCssHeight          :: Int
  , dlTextureCoordinates :: [Double]
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | The parsed ink, or the fallback when the custom property is missing or
-- not a plain hex color.
ditherColor :: MisoString -> Rgb
ditherColor value = case parseColor value of
  Just color -> color
  Nothing    -> fallbackColor
-----------------------------------------------------------------------------
-- | Accepts @#rgb@ and @#rrggbb@, with or without the leading @#@. Anything
-- else -- including @rgb(...)@ -- falls back, matching the source.
parseColor :: MisoString -> Maybe Rgb
parseColor value = do
  let trimmed = trim (fromMisoString value)
      source = maybe trimmed id (stripHash trimmed)
  normalized <- case length source of
    3 -> Just (concatMap (\digit -> [digit, digit]) source)
    6 -> Just source
    _ -> Nothing
  if all isHexDigit normalized
    then do
      let parsed = foldl' (\acc digit -> acc * 16 + digitToInt digit) 0 normalized
      pure Rgb
        { rgbRed = channel (shiftR parsed 16 .&. 255)
        , rgbGreen = channel (shiftR parsed 8 .&. 255)
        , rgbBlue = channel (parsed .&. 255)
        }
    else Nothing
  where
    stripHash text = case text of
      ('#' : rest) -> Just rest
      _            -> Nothing
    trim = dropWhileEnd isSpace . dropWhile isSpace
-----------------------------------------------------------------------------
channel :: Int -> Double
channel value = fromIntegral value / 255.0
-----------------------------------------------------------------------------
-- | The coral the site uses when no ink is declared.
fallbackColor :: Rgb
fallbackColor = Rgb
  { rgbRed = 1.0
  , rgbGreen = 75.0 / 255.0
  , rgbBlue = 38.0 / 255.0
  }
-----------------------------------------------------------------------------
-- | Backs the canvas at 1..2x the device ratio, then letterboxes the source
-- inside it: the texture is cropped, centered, on whichever axis overflows.
ditherLayout :: DitherLayoutInput -> DitherLayout
ditherLayout input = DitherLayout
  { dlCanvasWidth = rasterCanvasWidth raster
  , dlCanvasHeight = rasterCanvasHeight raster
  , dlCssWidth = rasterCssWidth raster
  , dlCssHeight = rasterCssHeight raster
  , dlTextureCoordinates =
      [ left, bottom
      , 1.0 - left, bottom
      , left, 1.0 - bottom
      , 1.0 - left, 1.0 - bottom
      ]
  }
  where
    raster = rasterLayout
      (dliWidth input)
      (dliHeight input)
      (dliDevicePixelRatio input)
      1.0
      2.0
    sourceRatio = dliSourceWidth input / dliSourceHeight input
    canvasRatio = fromIntegral (rasterCanvasWidth raster)
      / fromIntegral (rasterCanvasHeight raster)
    scale = if sourceRatio > canvasRatio
      then canvasRatio / sourceRatio
      else sourceRatio / canvasRatio
    left = if sourceRatio > canvasRatio then (1.0 - scale) / 2.0 else 0.0
    bottom = if sourceRatio > canvasRatio then 0.0 else (1.0 - scale) / 2.0
-----------------------------------------------------------------------------
-- | The source's ~20fps gate. Under reduced motion every scheduled frame is
-- drawn -- the loop only ever schedules one.
shouldDrawFrame :: Bool -> Double -> Double -> Bool
shouldDrawFrame reduceMotion timestamp previousTimestamp =
  reduceMotion || timestamp - previousTimestamp >= 50.0
-----------------------------------------------------------------------------
-- | A triangle strip covering the clip space, counter-clockwise from the
-- bottom-left.
quadVertices :: [Int]
quadVertices = [-1, -1, 1, -1, -1, 1, 1, 1]
-----------------------------------------------------------------------------
-- | The 4x4 ordered dithering matrix, repeated across the canvas by the
-- texture wrap.
bayerMatrix :: [Int]
bayerMatrix =
  [ 0, 192, 48, 240
  , 128, 64, 176, 112
  , 32, 224, 16, 208
  , 160, 96, 144, 80
  ]
