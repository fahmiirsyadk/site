module FFI
  ( afterPaint
  , applyThemeMode
  , everyMsInterval
  , fetchText
  , getStoredThemeMode
  , initMarkdownProseDelegation
  , interceptLinks
  , measureToolCards
  , parseIsoToMillis
  , patchRelativeDates
  , patchSsrThemeButtons
  , runWhenIdle
  , scrollToHashId
  , setupScrollSpy
  , tickScrollSpy
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Web.DOM.Node (Node)

-- DOM / Browser primitives

foreign import runWhenIdle :: Effect Unit -> Effect Unit
foreign import afterPaint :: Effect Unit -> Effect Unit
foreign import everyMsInterval :: Int -> Effect Unit -> Effect Unit
foreign import fetchText :: String -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect Unit

-- Theme

foreign import getStoredThemeMode :: Effect String
foreign import applyThemeMode :: String -> Effect Unit
foreign import patchSsrThemeButtons :: String -> Effect Unit

-- Anchor / scroll

foreign import scrollToHashIdImpl :: EffectFn1 String Unit

scrollToHashId :: String -> Effect Unit
scrollToHashId = runEffectFn1 scrollToHashIdImpl

-- TOC scroll spy

foreign import setupScrollSpyImpl :: EffectFn2 String (Nullable String -> Effect Unit) Unit
foreign import tickScrollSpyImpl :: EffectFn1 String Unit

setupScrollSpy :: String -> (Maybe String -> Effect Unit) -> Effect Unit
setupScrollSpy containerId callback =
  runEffectFn2 setupScrollSpyImpl containerId (\nullable -> callback (toMaybe nullable))

tickScrollSpy :: String -> Effect Unit
tickScrollSpy containerId = runEffectFn1 tickScrollSpyImpl containerId

-- Route / link interception

foreign import interceptLinksImpl :: EffectFn3 Node (String -> Effect Unit) (String -> Effect Unit) (Effect Unit)

interceptLinks :: Node -> (String -> Effect Unit) -> (String -> Effect Unit) -> Effect (Effect Unit)
interceptLinks = runEffectFn3 interceptLinksImpl

-- Island delegation (tool cards, terminal, copy)

foreign import initMarkdownProseDelegation :: Node -> Effect Unit

-- Tool card measurement

foreign import measureToolCards :: (String -> Int -> Effect Unit) -> Effect Unit

-- Date / relative time

foreign import parseIsoToMillis :: String -> Number
foreign import patchRelativeDates :: Effect Unit
