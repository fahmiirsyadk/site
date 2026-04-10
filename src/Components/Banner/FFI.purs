module Components.Banner.FFI
  ( BannerHandle
  , disposeBanner
  , initBanner
  , setBannerImage
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, EffectFn4, runEffectFn1, runEffectFn3, runEffectFn4)
import Web.DOM.Element (Element)

foreign import data BannerHandle :: Type

foreign import initBannerImpl ::
  EffectFn3
    Element
    String
    String
    (Nullable BannerHandle)

initBanner :: Element -> String -> String -> Effect (Maybe BannerHandle)
initBanner canvas vertexShader fragmentShader =
  map toMaybe (runEffectFn3 initBannerImpl canvas vertexShader fragmentShader)

-- | Set the banner image and dither colors.
-- | `colorLight` and `colorDark` are hex strings, e.g. "#FF4B26".
foreign import setBannerImageImpl ::
  EffectFn4
    BannerHandle
    String -- src
    String -- colorLight (hex)
    String -- colorDark (hex)
    Unit

setBannerImage :: BannerHandle -> String -> String -> String -> Effect Unit
setBannerImage h src light dark = runEffectFn4 setBannerImageImpl h src light dark

foreign import disposeBannerImpl :: EffectFn1 BannerHandle Unit

disposeBanner :: BannerHandle -> Effect Unit
disposeBanner = runEffectFn1 disposeBannerImpl
