module Platform.Browser where

import Prelude

import Foldkit.Mount (Element)
import PursTs.Effect as Fx

foreign import data BrowserError :: Type
foreign import data Cleanup :: Type

type GitHubActivity =
  { contributions :: Int
  , followers :: Int
  , levels :: Array Int
  }

type DocumentMetadata =
  { title :: String
  , description :: String
  , image :: String
  , contentType :: String
  }

foreign import afterPaint
  :: Fx.Effect Fx.Never Fx.NoServices Unit

foreign import prefersReducedMotion
  :: Fx.Effect Fx.Never Fx.NoServices Boolean

foreign import pushUrl
  :: String -> Fx.Effect BrowserError Fx.NoServices Unit

foreign import loadExternal
  :: String -> Fx.Effect BrowserError Fx.NoServices Unit

foreign import loadGitHub
  :: String -> Fx.Effect BrowserError Fx.NoServices GitHubActivity

foreign import copyPostLink
  :: String -> Fx.Effect BrowserError Fx.NoServices Unit

foreign import readTheme
  :: Fx.Effect BrowserError Fx.NoServices String

foreign import persistTheme
  :: String -> Fx.Effect BrowserError Fx.NoServices Unit

foreign import resetScroll
  :: Fx.Effect BrowserError Fx.NoServices Unit

foreign import syncDocumentMetadata
  :: DocumentMetadata -> Fx.Effect BrowserError Fx.NoServices Unit

foreign import acquireDitheredImage
  :: Element -> Fx.Effect BrowserError Fx.NoServices Cleanup

foreign import acquireHollowMark
  :: Element -> Fx.Effect BrowserError Fx.NoServices Cleanup

foreign import acquireRandomScribble
  :: Element -> Fx.Effect BrowserError Fx.NoServices Cleanup

foreign import acquireSeaShader
  :: Element -> Fx.Effect BrowserError Fx.NoServices Cleanup

foreign import release
  :: Cleanup -> Fx.Effect Fx.Never Fx.NoServices Unit
