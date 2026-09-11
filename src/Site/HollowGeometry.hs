-----------------------------------------------------------------------------
-- | The hollow mark's mesh, ported from the source's @Runtime.HollowGeometry@.
-- Two hemispherical shells per side, a rim cap, and the cube that travels
-- through them. Vertices are laid out as seven floats per vertex:
-- position (3), normal (3), region (1).
--
-- The native build step evaluates this construction into a packed payload;
-- this module is the single source of the geometry. The browser widget
-- decodes that payload instead of evaluating this trigonometric list at mount.
module Site.HollowGeometry
  ( hollowVertices
  , hollowVertexCount
  ) where
-----------------------------------------------------------------------------
radialSegments :: Int
radialSegments = 28
-----------------------------------------------------------------------------
ringSegments :: Int
ringSegments = 64
-----------------------------------------------------------------------------
outerRadius, innerRadius :: Double
outerRadius = 1.0
innerRadius = 0.94
-----------------------------------------------------------------------------
type Point = (Double, Double, Double)
-----------------------------------------------------------------------------
point :: Double -> Double -> Double -> Double -> Point
point radius side theta phi =
  ( side * radius * cos theta
  , radius * sin theta * cos phi
  , radius * sin theta * sin phi
  )
-----------------------------------------------------------------------------
surfaceNormal :: Double -> Point -> Point
surfaceNormal direction (x, y, z) =
  ( x / magnitude * direction
  , y / magnitude * direction
  , z / magnitude * direction
  )
  where
    magnitude = sqrt (x * x + y * y + z * z)
-----------------------------------------------------------------------------
vertex :: Point -> Point -> Double -> [Double]
vertex (x, y, z) (nx, ny, nz) region =
  [x, y, z, nx, ny, nz, region]
-----------------------------------------------------------------------------
triangle :: Point -> Point -> Point -> Point -> Point -> Point -> Double -> [Double]
triangle a b c normalA normalB normalC region =
  vertex a normalA region
    <> vertex b normalB region
    <> vertex c normalC region
-----------------------------------------------------------------------------
surfaceCell
  :: Double -> Double -> Double -> Double
  -> Int -> Int -> [Double]
surfaceCell radius side direction region radialIndex ringIndex =
  triangle a b c normalA normalB normalC region
    <> triangle c b d normalC normalB normalD region
  where
    radial = fromIntegral radialIndex
    ring = fromIntegral ringIndex
    radialCount = fromIntegral radialSegments
    ringCount = fromIntegral ringSegments
    thetaA = radial / radialCount * pi * 0.5
    thetaB = (radial + 1.0) / radialCount * pi * 0.5
    phiA = ring / ringCount * pi * 2.0
    phiB = (ring + 1.0) / ringCount * pi * 2.0
    a = point radius side thetaA phiA
    b = point radius side thetaB phiA
    c = point radius side thetaA phiB
    d = point radius side thetaB phiB
    normalA = surfaceNormal direction a
    normalB = surfaceNormal direction b
    normalC = surfaceNormal direction c
    normalD = surfaceNormal direction d
-----------------------------------------------------------------------------
surface :: Double -> Double -> Double -> Double -> [Double]
surface radius side direction region =
  concatMap outer [0 .. radialSegments - 1]
  where
    outer radialIndex =
      concatMap
        (surfaceCell radius side direction region radialIndex)
        [0 .. ringSegments - 1]
-----------------------------------------------------------------------------
rimCell :: Double -> Double -> Int -> [Double]
rimCell side region ringIndex =
  triangle outerA innerA outerB normal normal normal region
    <> triangle outerB innerA innerB normal normal normal region
  where
    ring = fromIntegral ringIndex
    ringCount = fromIntegral ringSegments
    phiA = ring / ringCount * pi * 2.0
    phiB = (ring + 1.0) / ringCount * pi * 2.0
    outerA = (0.0, outerRadius * cos phiA, outerRadius * sin phiA)
    outerB = (0.0, outerRadius * cos phiB, outerRadius * sin phiB)
    innerA = (0.0, innerRadius * cos phiA, innerRadius * sin phiA)
    innerB = (0.0, innerRadius * cos phiB, innerRadius * sin phiB)
    normal = (-side, 0.0, 0.0)
-----------------------------------------------------------------------------
rim :: Double -> Double -> [Double]
rim side region = concatMap (rimCell side region) [0 .. ringSegments - 1]
-----------------------------------------------------------------------------
cubePoint :: Double -> Double -> Double -> Point
cubePoint x y z = (x * halfSize, y * halfSize, z * halfSize)
  where
    halfSize = 0.20
-----------------------------------------------------------------------------
cubeFace :: Point -> Point -> Point -> Point -> Point -> [Double]
cubeFace a b c d normal =
  triangle a b c normal normal normal 6.0
    <> triangle c b d normal normal normal 6.0
-----------------------------------------------------------------------------
cube :: [Double]
cube =
  cubeFace
    (cubePoint 1.0 (-1.0) (-1.0)) (cubePoint 1.0 1.0 (-1.0))
    (cubePoint 1.0 (-1.0) 1.0) (cubePoint 1.0 1.0 1.0)
    (1.0, 0.0, 0.0)
    <> cubeFace
      (cubePoint (-1.0) (-1.0) 1.0) (cubePoint (-1.0) 1.0 1.0)
      (cubePoint (-1.0) (-1.0) (-1.0)) (cubePoint (-1.0) 1.0 (-1.0))
      (-1.0, 0.0, 0.0)
    <> cubeFace
      (cubePoint (-1.0) 1.0 (-1.0)) (cubePoint (-1.0) 1.0 1.0)
      (cubePoint 1.0 1.0 (-1.0)) (cubePoint 1.0 1.0 1.0)
      (0.0, 1.0, 0.0)
    <> cubeFace
      (cubePoint (-1.0) (-1.0) 1.0) (cubePoint (-1.0) (-1.0) (-1.0))
      (cubePoint 1.0 (-1.0) 1.0) (cubePoint 1.0 (-1.0) (-1.0))
      (0.0, (-1.0), 0.0)
    <> cubeFace
      (cubePoint 1.0 (-1.0) 1.0) (cubePoint 1.0 1.0 1.0)
      (cubePoint (-1.0) (-1.0) 1.0) (cubePoint (-1.0) 1.0 1.0)
      (0.0, 0.0, 1.0)
    <> cubeFace
      (cubePoint (-1.0) (-1.0) (-1.0)) (cubePoint (-1.0) 1.0 (-1.0))
      (cubePoint 1.0 (-1.0) (-1.0)) (cubePoint 1.0 1.0 (-1.0))
      (0.0, 0.0, (-1.0))
-----------------------------------------------------------------------------
hollowVertices :: [Double]
hollowVertices =
  surface outerRadius (-1.0) 1.0 0.0
    <> surface innerRadius (-1.0) (-1.0) 1.0
    <> rim (-1.0) 2.0
    <> surface outerRadius 1.0 1.0 3.0
    <> surface innerRadius 1.0 (-1.0) 4.0
    <> rim 1.0 5.0
    <> cube
-----------------------------------------------------------------------------
hollowVertexCount :: Int
hollowVertexCount =
  -- Four surfaces, two rims, and six cube faces. Keep this arithmetic
  -- independent of 'hollowVertices': the browser widget only needs the count
  -- and must not force the trigonometric reference list during startup.
  4 * radialSegments * ringSegments * 2 * 3
    + 2 * ringSegments * 2 * 3
    + 6 * 2 * 3
