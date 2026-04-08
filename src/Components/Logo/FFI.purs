-- | WebGL1 + animation loop FFI. The Pursuit package `purescript-webgl` (2.0.1) targets older
-- | PureScript (`Eff`, pre–ES modules) and is not in the current registry; this is the small
-- | boundary layer. Shader strings, mesh data, and matrices live in PureScript.
module Components.Logo.FFI
  ( LogoHandle
  , logoBufferAspect
  , logoDraw
  , logoInit
  , logoSetupScene
  , performanceNowMillis
  , raf
  ) where

import Prelude

import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn5, EffectFn6, runEffectFn1, runEffectFn2, runEffectFn5, runEffectFn6)
import Web.DOM.Element (Element)

foreign import data LogoHandle :: Type

-- | Returns `null` when WebGL init or shader link fails.
foreign import logoInitImpl ::
  EffectFn6
    Element
    String
    String
    (Array Number)
    (Array Number)
    (Array Int)
    (Nullable LogoHandle)

logoInit ::
  Element
  -> String
  -> String
  -> Array Number
  -> Array Number
  -> Array Int
  -> Effect (Nullable LogoHandle)
logoInit canvas vertexShader fragmentShader pos norm idx =
  runEffectFn6 logoInitImpl canvas vertexShader fragmentShader pos norm idx

foreign import logoBufferAspectImpl :: EffectFn1 LogoHandle Number

logoBufferAspect :: LogoHandle -> Effect Number
logoBufferAspect = runEffectFn1 logoBufferAspectImpl

-- | One-time scene setup: projection matrix, light position, constant uniforms,
-- | static GL state, and vertex attribute bindings.
foreign import logoSetupSceneImpl ::
  EffectFn5
    LogoHandle
    (Array Number)
    Number
    Number
    Number
    Unit

logoSetupScene ::
  LogoHandle
  -> Array Number
  -> Number
  -> Number
  -> Number
  -> Effect Unit
logoSetupScene handle proj lx ly lz =
  runEffectFn5 logoSetupSceneImpl handle proj lx ly lz

-- | Hot-path draw: only updates model-view matrix and issues the draw call.
foreign import logoDrawImpl :: EffectFn2 LogoHandle (Array Number) Unit

logoDraw :: LogoHandle -> Array Number -> Effect Unit
logoDraw handle mvCol = runEffectFn2 logoDrawImpl handle mvCol

foreign import performanceNowMillis :: Effect Number

foreign import rafImpl :: EffectFn1 (Effect Unit) Unit

raf :: Effect Unit -> Effect Unit
raf = runEffectFn1 rafImpl
