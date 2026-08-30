module Platform.Browser where

import Prelude

import PursTs.Effect as Fx

foreign import data BrowserError :: Type
foreign import data Cleanup :: Type

type DocumentMetadata =
  { title :: String
  , description :: String
  , image :: String
  , contentType :: String
  }

foreign import resetScroll
  :: Fx.Effect BrowserError Fx.NoServices Unit

foreign import syncDocumentMetadata
  :: DocumentMetadata -> Fx.Effect BrowserError Fx.NoServices Unit

foreign import release
  :: Cleanup -> Fx.Effect Fx.Never Fx.NoServices Unit
