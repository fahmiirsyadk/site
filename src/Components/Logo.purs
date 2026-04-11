module Components.Logo
  ( cubeLogoLink
  , mountCubeLogo
  ) where

import Prelude

import Components.Logo.FFI (LogoHandle)
import Components.Logo.FFI as FFI
import Components.Logo.Geometry as Geo
import Components.Logo.Math as LM
import Data.Array as Array
import Data.Array (mapMaybe, null)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Data.TransformationMatrix.Matrix4 as M
import Data.TransformationMatrix.Rotation (Radians(..))
import Data.TransformationMatrix.Vector3 (Vector3(..))
import Defer (runWhenIdle)
import Effect (Effect)
import Effect.Ref as Ref
import Data.Foldable (for_)
import Luna.Html (Html, attr)
import Luna.Html as H
import Web.DOM.Document as Document
import Web.DOM.Element as DOMElement
import Web.DOM.Node as Node
import Web.DOM.NodeList as NodeList
import Web.DOM.ParentNode (QuerySelector(..), querySelector, querySelectorAll) as PN
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window (document)

-- | GLSL ES 1.00 — uniforms for MVP and model–view (typed row in PS, column-mapped for GL).
vertexShader :: String
vertexShader =
  """
attribute vec3 aPosition;
attribute vec3 aNormal;
uniform mat4 uProjectionMatrix;
uniform mat4 uModelViewMatrix;
varying vec3 vNormal;
varying vec3 vPosition;

void main(void) {
  mat3 normalMatrix = mat3(
    uModelViewMatrix[0].xyz,
    uModelViewMatrix[1].xyz,
    uModelViewMatrix[2].xyz
  );
  vNormal = normalize(normalMatrix * aNormal);
  vec4 mv = uModelViewMatrix * vec4(aPosition, 1.0);
  vPosition = mv.xyz;
  gl_Position = uProjectionMatrix * mv;
}
"""

fragmentShader :: String
fragmentShader =
  """
#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 uColorLight;
uniform vec3 uColorDark;
uniform vec3 uLightPosition;
uniform vec2 uResolution;

varying vec3 vNormal;
varying vec3 vPosition;

// Bayer 8x8 via bit-decomposition: extracts (x_i XOR y_i, y_i) pairs and
// reverse-interleaves them into the 6-bit threshold. Branchless, 3 iterations.
float bayerMatrix8x8(vec2 coord) {
  vec2 p = mod(coord, 8.0);
  float result = 0.0;
  float w = 32.0;
  float d = 1.0;
  for (int i = 0; i < 3; i++) {
    vec2 b = mod(floor(p / d), 2.0);
    result += (b.x + b.y - 2.0 * b.x * b.y) * w;
    w *= 0.5;
    result += b.y * w;
    w *= 0.5;
    d *= 2.0;
  }
  return result / 64.0;
}

void main(void) {
  vec3 lightDir = normalize(uLightPosition - vPosition);
  float diffuse = max(dot(vNormal, lightDir), 0.0);
  float intensity = diffuse * 0.6;
  vec2 screenCoord = gl_FragCoord.xy;
  float threshold = bayerMatrix8x8(screenCoord);
  vec3 color = intensity > threshold ? uColorLight : uColorDark;
  gl_FragColor = vec4(color, 1.0);
}
"""

-- | 50° vertical FOV in radians (matches previous implementation).
fovRad50 :: Number
fovRad50 = 50.0 * 3.141592653589793 / 180.0

viewMatrix :: M.Matrix4
viewMatrix = M.translate (Vector3 0.0 0.0 (-5.0)) M.identity4

modelFromAngles :: Number -> Number -> M.Matrix4
modelFromAngles rx ry =
  M.multiply (M.rotateMatrixYAxis M.identity4 (Radians ry)) (M.rotateMatrixXAxis M.identity4 (Radians rx))

lightInViewSpace :: M.Matrix4 -> Vector3 Number
lightInViewSpace view =
  case M.applyMatrix4 view (Vector3 50.0 50.0 50.0) of
    Right v -> v
    Left _ -> Vector3 50.0 50.0 45.0

-- | Home link; WebGL mounts into every `[data-cube-logo-host]` (sidebar + mobile).
-- | `compact` uses a smaller cube for the top bar.
cubeLogoLink :: forall i. String -> Boolean -> Html i
cubeLogoLink href compact =
  H.a
    [ H.href href
    , H.classes [ "no-underline", "block", "outline-none" ]
    , attr "aria-label" "Home"
    ]
    [ H.div
        ( [ attr "data-cube-logo-host" "true"
          , attr "data-logo-px" (if compact then "36" else "60")
          ]
            <>
              [ H.classes
                  ( [ "flex"
                    , "items-center"
                    , "justify-center"
                    ]
                      <>
                        if compact then
                          [ "h-9"
                          , "w-9"
                          ]
                        else
                          [ "h-[60px]"
                          , "w-[60px]"
                          ]
                  )
              ]
        )
        []
    ]
type Anim =
  { rx :: Number
  , ry :: Number
  , last :: Number
  }

mountCubeLogo :: Effect Unit
mountCubeLogo = do
  htmlDoc <- window >>= document
  let
    doc = HTMLDocument.toDocument htmlDoc
    parent = HTMLDocument.toParentNode htmlDoc
  nl <- PN.querySelectorAll (PN.QuerySelector "[data-cube-logo-host]") parent
  nodes <- NodeList.toArray nl
  let
    elems = mapMaybe DOMElement.fromNode nodes
  case elems of
    [] ->
      pure unit
    _ -> do
      handlesAcc <- Ref.new ([] :: Array LogoHandle)
      let
        startAnim :: Array LogoHandle -> Effect Unit
        startAnim handles =
          if null handles then
            pure unit
          else do
            ref <- Ref.new { rx: 0.5, ry: 0.5, last: 0.0 }
            let
              loop :: Effect Unit
              loop = do
                now <- FFI.performanceNowMillis
                st <- Ref.read ref
                let
                  delta = min 0.05 $ (now - st.last) / 1000.0
                  rx = st.rx + delta * 0.2
                  ry = st.ry + delta * 0.2
                Ref.write { rx, ry, last: now } ref
                let
                  model = modelFromAngles rx ry
                  modelView = M.multiply viewMatrix model
                  mvCol = LM.matrix4ToColumnMajor modelView
                for_ handles \h -> FFI.logoDraw h mvCol
                FFI.raf loop
            FFI.raf loop

        mountRest :: Array DOMElement.Element -> Effect Unit
        mountRest els =
          case Array.uncons els of
            Nothing -> do
              handles <- Ref.read handlesAcc
              startAnim handles
            Just { head: el, tail: rest } -> do
              mh <- mountLogoIntoHost doc el
              case mh of
                Just h -> Ref.modify_ (\xs -> Array.snoc xs h) handlesAcc
                Nothing -> pure unit
              runWhenIdle (mountRest rest)
      runWhenIdle (mountRest elems)

mountLogoIntoHost :: Document.Document -> DOMElement.Element -> Effect (Maybe LogoHandle)
mountLogoIntoHost doc container = do
  mbExisting <- PN.querySelector (PN.QuerySelector "canvas") (DOMElement.toParentNode container)
  case mbExisting of
    Just _ ->
      pure Nothing
    Nothing -> do
      canvas <- Document.createElement "canvas" doc
      DOMElement.setAttribute "style" "display:block;width:100%;height:100%;touch-action:none;pointer-events:none;" canvas
      _ <- Node.appendChild (DOMElement.toNode canvas) (DOMElement.toNode container)
      mh <- FFI.logoInit canvas vertexShader fragmentShader Geo.positions Geo.normals Geo.indices
      case toMaybe mh of
        Nothing ->
          pure Nothing
        Just h -> do
          aspect <- FFI.logoBufferAspect h
          let
            proj = LM.perspectiveColumnMajor fovRad50 aspect 0.1 100.0
            Vector3 lx ly lz = lightInViewSpace viewMatrix
          FFI.logoSetupScene h proj lx ly lz
          pure (Just h)
