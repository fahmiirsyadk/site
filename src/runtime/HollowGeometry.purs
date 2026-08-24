module Runtime.HollowGeometry where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Number as Number

type Point =
  { x :: Number
  , y :: Number
  , z :: Number
  }

radialSegments :: Int
radialSegments = 28

ringSegments :: Int
ringSegments = 64

outerRadius :: Number
outerRadius = 1.0

innerRadius :: Number
innerRadius = 0.94

point :: Number -> Number -> Number -> Number -> Point
point radius side theta phi =
  { x: side * radius * Number.cos theta
  , y: radius * Number.sin theta * Number.cos phi
  , z: radius * Number.sin theta * Number.sin phi
  }

surfaceNormal :: Number -> Point -> Point
surfaceNormal direction value =
  let magnitude = Number.sqrt (value.x * value.x + value.y * value.y + value.z * value.z)
  in
    { x: value.x / magnitude * direction
    , y: value.y / magnitude * direction
    , z: value.z / magnitude * direction
    }

vertex :: Point -> Point -> Number -> Array Number
vertex position normal region =
  [ position.x, position.y, position.z
  , normal.x, normal.y, normal.z
  , region
  ]

triangle :: Point -> Point -> Point -> Point -> Point -> Point -> Number -> Array Number
triangle a b c normalA normalB normalC region = Array.concat
  [ vertex a normalA region
  , vertex b normalB region
  , vertex c normalC region
  ]

surfaceCell :: Number -> Number -> Number -> Number -> Int -> Int -> Array Number
surfaceCell radius side direction region radialIndex ringIndex =
  let radial = Int.toNumber radialIndex
      ring = Int.toNumber ringIndex
      radialCount = Int.toNumber radialSegments
      ringCount = Int.toNumber ringSegments
      thetaA = radial / radialCount * Number.pi * 0.5
      thetaB = (radial + 1.0) / radialCount * Number.pi * 0.5
      phiA = ring / ringCount * Number.pi * 2.0
      phiB = (ring + 1.0) / ringCount * Number.pi * 2.0
      a = point radius side thetaA phiA
      b = point radius side thetaB phiA
      c = point radius side thetaA phiB
      d = point radius side thetaB phiB
  in Array.concat
    [ triangle a b c (surfaceNormal direction a) (surfaceNormal direction b) (surfaceNormal direction c) region
    , triangle c b d (surfaceNormal direction c) (surfaceNormal direction b) (surfaceNormal direction d) region
    ]

surface :: Number -> Number -> Number -> Number -> Array Number
surface radius side direction region = Array.concatMap
  (\radialIndex -> Array.concatMap
    (surfaceCell radius side direction region radialIndex)
    (Array.range 0 (ringSegments - 1)))
  (Array.range 0 (radialSegments - 1))

rimCell :: Number -> Number -> Int -> Array Number
rimCell side region ringIndex =
  let ring = Int.toNumber ringIndex
      ringCount = Int.toNumber ringSegments
      phiA = ring / ringCount * Number.pi * 2.0
      phiB = (ring + 1.0) / ringCount * Number.pi * 2.0
      outerA = { x: 0.0, y: outerRadius * Number.cos phiA, z: outerRadius * Number.sin phiA }
      outerB = { x: 0.0, y: outerRadius * Number.cos phiB, z: outerRadius * Number.sin phiB }
      innerA = { x: 0.0, y: innerRadius * Number.cos phiA, z: innerRadius * Number.sin phiA }
      innerB = { x: 0.0, y: innerRadius * Number.cos phiB, z: innerRadius * Number.sin phiB }
      normal = { x: -side, y: 0.0, z: 0.0 }
  in Array.concat
    [ triangle outerA innerA outerB normal normal normal region
    , triangle outerB innerA innerB normal normal normal region
    ]

rim :: Number -> Number -> Array Number
rim side region = Array.concatMap (rimCell side region) (Array.range 0 (ringSegments - 1))

cubePoint :: Number -> Number -> Number -> Point
cubePoint x y z =
  let halfSize = 0.20
  in { x: x * halfSize, y: y * halfSize, z: z * halfSize }

cubeFace :: Point -> Point -> Point -> Point -> Point -> Array Number
cubeFace a b c d normal = Array.concat
  [ triangle a b c normal normal normal 6.0
  , triangle c b d normal normal normal 6.0
  ]

cube :: Array Number
cube = Array.concat
  [ cubeFace
      (cubePoint 1.0 (-1.0) (-1.0)) (cubePoint 1.0 1.0 (-1.0))
      (cubePoint 1.0 (-1.0) 1.0) (cubePoint 1.0 1.0 1.0)
      { x: 1.0, y: 0.0, z: 0.0 }
  , cubeFace
      (cubePoint (-1.0) (-1.0) 1.0) (cubePoint (-1.0) 1.0 1.0)
      (cubePoint (-1.0) (-1.0) (-1.0)) (cubePoint (-1.0) 1.0 (-1.0))
      { x: -1.0, y: 0.0, z: 0.0 }
  , cubeFace
      (cubePoint (-1.0) 1.0 (-1.0)) (cubePoint (-1.0) 1.0 1.0)
      (cubePoint 1.0 1.0 (-1.0)) (cubePoint 1.0 1.0 1.0)
      { x: 0.0, y: 1.0, z: 0.0 }
  , cubeFace
      (cubePoint (-1.0) (-1.0) 1.0) (cubePoint (-1.0) (-1.0) (-1.0))
      (cubePoint 1.0 (-1.0) 1.0) (cubePoint 1.0 (-1.0) (-1.0))
      { x: 0.0, y: -1.0, z: 0.0 }
  , cubeFace
      (cubePoint 1.0 (-1.0) 1.0) (cubePoint 1.0 1.0 1.0)
      (cubePoint (-1.0) (-1.0) 1.0) (cubePoint (-1.0) 1.0 1.0)
      { x: 0.0, y: 0.0, z: 1.0 }
  , cubeFace
      (cubePoint (-1.0) (-1.0) (-1.0)) (cubePoint (-1.0) 1.0 (-1.0))
      (cubePoint 1.0 (-1.0) (-1.0)) (cubePoint 1.0 1.0 (-1.0))
      { x: 0.0, y: 0.0, z: -1.0 }
  ]

hollowVertices :: Array Number
hollowVertices = Array.concat
  [ surface outerRadius (-1.0) 1.0 0.0
  , surface innerRadius (-1.0) (-1.0) 1.0
  , rim (-1.0) 2.0
  , surface outerRadius 1.0 1.0 3.0
  , surface innerRadius 1.0 (-1.0) 4.0
  , rim 1.0 5.0
  , cube
  ]

hollowVertexCount :: Int
hollowVertexCount = Array.length hollowVertices / 7
