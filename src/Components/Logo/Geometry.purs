module Components.Logo.Geometry (positions, normals, indices) where

import Prelude

import Data.Array (concat, replicate)

-- | 24 vertices (6 faces × 4 corners), 36 indices — total edge length 2.5 (half-extent 1.25).
positions :: Array Number
positions =
  concat
    [ concat ff
    , concat bf
    , concat rf
    , concat lf
    , concat tf
    , concat bo
    ]
  where
  s = 1.25
  ff = [ [ -s, -s, s ], [ s, -s, s ], [ s, s, s ], [ -s, s, s ] ]
  bf = [ [ s, -s, -s ], [ -s, -s, -s ], [ -s, s, -s ], [ s, s, -s ] ]
  rf = [ [ s, -s, -s ], [ s, -s, s ], [ s, s, s ], [ s, s, -s ] ]
  lf = [ [ -s, -s, s ], [ -s, -s, -s ], [ -s, s, -s ], [ -s, s, s ] ]
  tf = [ [ -s, s, -s ], [ s, s, -s ], [ s, s, s ], [ -s, s, s ] ]
  bo = [ [ -s, -s, s ], [ s, -s, s ], [ s, -s, -s ], [ -s, -s, -s ] ]

normals :: Array Number
normals =
  concat
    [ face 0.0 0.0 1.0
    , face 0.0 0.0 (-1.0)
    , face 1.0 0.0 0.0
    , face (-1.0) 0.0 0.0
    , face 0.0 1.0 0.0
    , face 0.0 (-1.0) 0.0
    ]
  where
  face nx ny nz = concat (replicate 4 [ nx, ny, nz ])

indices :: Array Int
indices =
  concat $ map faceIndices [ 0, 4, 8, 12, 16, 20 ]
  where
  faceIndices base = [ base, base + 1, base + 2, base, base + 2, base + 3 ]
