{-# LANGUAGE OverloadedStrings #-}

-- | The app owns widget resources; neither views nor module-global refs do.
module Site.Widgets.Runtime
  ( Runtime (..), newRuntime, disposeRuntime ) where

import Control.Monad (void, when)
import Data.Maybe (isJust)
import Miso.DSL (JSVal, fromJSVal, (!), (#))
import Miso.String (MisoString)
import qualified Site.Scroll as Scroll
import qualified Site.Widgets.Browser as Browser
import qualified Site.Widgets.Dither as Dither
import qualified Site.Widgets.Hollow as Hollow
import qualified Site.Widgets.Scribble as Scribble
import qualified Site.Widgets.Sea as Sea

data Runtime = Runtime
  { sea :: Browser.Mount
  , hollow :: Browser.Mount
  , scribble :: Browser.Mount
  , readingSlider :: Browser.Mount
  , dither :: Dither.Registry
  }

-- Allocates ownership slots only; safe in native tests as well as the browser.
newRuntime :: IO Runtime
newRuntime = Runtime <$> Browser.newMount Sea.mount
  <*> Browser.newMount Hollow.mount <*> Browser.newMount Scribble.mount
  <*> Browser.newMount mountReadingSlider
  <*> Dither.newRegistry

disposeRuntime :: Runtime -> IO ()
disposeRuntime runtime = do
  Browser.disposeMount (sea runtime)
  Browser.disposeMount (hollow runtime)
  Browser.disposeMount (scribble runtime)
  Browser.disposeMount (readingSlider runtime)
  Dither.dispose (dither runtime)

mountReadingSlider :: Browser.Scope -> JSVal -> IO Bool
mountReadingSlider scope element = do
  Browser.listen scope element "keydown" False $ \event -> do
    key <- (fromJSVal =<< event ! "key") :: IO (Maybe MisoString)
    when (isJust (Scroll.progressCommand =<< key)) $
      void $ event # "preventDefault" $ ()
  pure True
