module Runtime.Canvas where

import Prelude

import Data.Int as Int

type RasterInput =
  { width :: Number
  , height :: Number
  , devicePixelRatio :: Number
  , minimumPixelRatio :: Number
  , maximumPixelRatio :: Number
  }

type RasterLayout =
  { canvasWidth :: Int
  , canvasHeight :: Int
  , cssWidth :: Int
  , cssHeight :: Int
  , pixelRatio :: Number
  }

rasterLayout :: RasterInput -> RasterLayout
rasterLayout input =
  let
    pixelRatio = min input.maximumPixelRatio (max input.minimumPixelRatio input.devicePixelRatio)
  in
    { canvasWidth: max 1 (Int.round (input.width * pixelRatio))
    , canvasHeight: max 1 (Int.round (input.height * pixelRatio))
    , cssWidth: Int.round input.width
    , cssHeight: Int.round input.height
    , pixelRatio
    }
