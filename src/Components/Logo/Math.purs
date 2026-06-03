module Components.Logo.Math (matrix4ToColumnMajor, perspectiveColumnMajor) where

import Prelude

import Data.Array as Array
import Data.Number (tan)
import Data.Maybe (fromMaybe)
import Data.TransformationMatrix.Matrix4 as M

-- | Row-major flat `Matrix4.toArray` → WebGL `uniformMatrix4fv` column-major order.
matrix4ToColumnMajor :: M.Matrix4 -> Array Number
matrix4ToColumnMajor mat =
  let
    r = M.toArray mat
    colIndex i = (i `mod` 4) * 4 + (i `div` 4)
  in
    map (\i -> fromMaybe 0.0 $ Array.index r (colIndex i)) $ Array.range 0 15

-- | Perspective projection matrix, column-major (intrinsic WebGL layout).
perspectiveColumnMajor :: Number -> Number -> Number -> Number -> Array Number
perspectiveColumnMajor fovRad aspect zNear zFar =
  let
    f = 1.0 / tan (fovRad / 2.0)
    nf = 1.0 / (zNear - zFar)
    a = (zFar + zNear) * nf
    b = 2.0 * zFar * zNear * nf
  in
    [ f / aspect, 0.0, 0.0, 0.0, 0.0, f, 0.0, 0.0, 0.0, 0.0, a, -1.0, 0.0, 0.0, b, 0.0 ]
