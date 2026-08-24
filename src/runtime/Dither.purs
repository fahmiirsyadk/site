module Runtime.Dither where

import Prelude

import Data.Int as Int
import Data.Int.Bits as Bits
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String as String
import Data.String.CodeUnits as CodeUnits
import Data.String.Pattern (Pattern(..))
import Runtime.Canvas as Canvas

type Rgb =
  { red :: Number
  , green :: Number
  , blue :: Number
  }

type DitherLayoutInput =
  { width :: Number
  , height :: Number
  , devicePixelRatio :: Number
  , sourceWidth :: Number
  , sourceHeight :: Number
  }

type DitherLayout =
  { canvasWidth :: Int
  , canvasHeight :: Int
  , cssWidth :: Int
  , cssHeight :: Int
  , textureCoordinates :: Array Number
  }

ditherColor :: String -> Rgb
ditherColor value =
  fromMaybe fallbackColor (parseColor value)

parseColor :: String -> Maybe Rgb
parseColor value = do
  let source = fromMaybe (String.trim value) (CodeUnits.stripPrefix (Pattern "#") (String.trim value))
  normalized <- case CodeUnits.length source of
    3 -> Just (duplicateDigit 0 source <> duplicateDigit 1 source <> duplicateDigit 2 source)
    6 -> Just source
    _ -> Nothing
  parsed <- Int.fromStringAs Int.hexadecimal normalized
  pure
    { red: channel (Bits.and (Bits.shr parsed 16) 255)
    , green: channel (Bits.and (Bits.shr parsed 8) 255)
    , blue: channel (Bits.and parsed 255)
    }

duplicateDigit :: Int -> String -> String
duplicateDigit index source =
  let digit = CodeUnits.take 1 (CodeUnits.drop index source)
  in digit <> digit

channel :: Int -> Number
channel value = Int.toNumber value / 255.0

fallbackColor :: Rgb
fallbackColor =
  { red: 1.0
  , green: 75.0 / 255.0
  , blue: 38.0 / 255.0
  }

ditherLayout :: DitherLayoutInput -> DitherLayout
ditherLayout input =
  let
    raster = Canvas.rasterLayout
      { width: input.width
      , height: input.height
      , devicePixelRatio: input.devicePixelRatio
      , minimumPixelRatio: 1.0
      , maximumPixelRatio: 2.0
      }
    sourceRatio = input.sourceWidth / input.sourceHeight
    canvasRatio = Int.toNumber raster.canvasWidth / Int.toNumber raster.canvasHeight
    scale = if sourceRatio > canvasRatio then canvasRatio / sourceRatio else sourceRatio / canvasRatio
    left = if sourceRatio > canvasRatio then (1.0 - scale) / 2.0 else 0.0
    bottom = if sourceRatio > canvasRatio then 0.0 else (1.0 - scale) / 2.0
  in
    { canvasWidth: raster.canvasWidth
    , canvasHeight: raster.canvasHeight
    , cssWidth: raster.cssWidth
    , cssHeight: raster.cssHeight
    , textureCoordinates:
        [ left, bottom
        , 1.0 - left, bottom
        , left, 1.0 - bottom
        , 1.0 - left, 1.0 - bottom
        ]
    }

shouldDrawFrame :: { reduceMotion :: Boolean, timestamp :: Number, previousTimestamp :: Number } -> Boolean
shouldDrawFrame input =
  input.reduceMotion || input.timestamp - input.previousTimestamp >= 50.0

quadVertices :: Array Number
quadVertices = [ -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0 ]

bayerMatrix :: Array Int
bayerMatrix =
  [ 0, 192, 48, 240
  , 128, 64, 176, 112
  , 32, 224, 16, 208
  , 160, 96, 144, 80
  ]
