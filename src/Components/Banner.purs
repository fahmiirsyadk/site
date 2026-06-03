module Components.Banner
  ( disposeBannerIfAny
  , mountBannerFilter
  ) where

import Prelude

import Components.Banner.FFI as FFI
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Web.DOM.ParentNode (QuerySelector(..), querySelector) as DOM
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window (document)

vertexShader :: String
vertexShader =
  """
attribute vec2 aPosition;
attribute vec2 aTexCoord;
varying vec2 vTexCoord;

void main(void) {
  vTexCoord = aTexCoord;
  gl_Position = vec4(aPosition, 0.0, 1.0);
}
"""

fragmentShader :: String
fragmentShader =
  """
#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D uTexture;
uniform vec3 uColorLight;
uniform vec3 uColorDark;
varying vec2 vTexCoord;

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
  vec4 tex = texture2D(uTexture, vTexCoord);
  float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
  float threshold = bayerMatrix8x8(gl_FragCoord.xy);
  vec3 color = lum > threshold ? uColorLight : uColorDark;
  gl_FragColor = vec4(color, tex.a);
}
"""

-- | Site accent orange for dark pixels on light site background.
colorLight :: String
colorLight = "#F5F5F5"

colorDark :: String
colorDark = "#FF4B26"

mountBannerFilter :: Maybe FFI.BannerHandle -> String -> Effect (Maybe FFI.BannerHandle)
mountBannerFilter current imageSrc = do
  doc <- window >>= document
  mbCanvas <- DOM.querySelector (DOM.QuerySelector "#article-banner-canvas") (HTMLDocument.toParentNode doc)
  case mbCanvas of
    Nothing -> pure current
    Just canvas ->
      case current of
        Just h -> do
          FFI.setBannerImage h imageSrc colorLight colorDark
          pure current
        Nothing -> do
          mh <- FFI.initBanner canvas vertexShader fragmentShader
          case mh of
            Nothing -> pure Nothing
            Just h -> do
              FFI.setBannerImage h imageSrc colorLight colorDark
              pure (Just h)

disposeBannerIfAny :: Maybe FFI.BannerHandle -> Effect (Maybe FFI.BannerHandle)
disposeBannerIfAny m = do
  case m of
    Nothing -> pure unit
    Just h -> FFI.disposeBanner h
  pure Nothing
