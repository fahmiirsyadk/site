-- | The app owns widget resources; neither views nor module-global refs do.
module Site.Widgets.Runtime
  ( Runtime (..), newRuntime, disposeRuntime ) where

import qualified Site.Widgets.Browser as Browser
import qualified Site.Widgets.Dither as Dither
import qualified Site.Widgets.Hollow as Hollow
import qualified Site.Widgets.Scribble as Scribble
import qualified Site.Widgets.Sea as Sea

data Runtime = Runtime
  { sea :: Browser.Mount
  , hollow :: Browser.Mount
  , scribble :: Browser.Mount
  , dither :: Dither.Registry
  }

-- Allocates ownership slots only; safe in native tests as well as the browser.
newRuntime :: IO Runtime
newRuntime = Runtime <$> Browser.newMount Sea.mount
  <*> Browser.newMount Hollow.mount <*> Browser.newMount Scribble.mount
  <*> Dither.newRegistry

disposeRuntime :: Runtime -> IO ()
disposeRuntime runtime = do
  Browser.disposeMount (sea runtime)
  Browser.disposeMount (hollow runtime)
  Browser.disposeMount (scribble runtime)
  Dither.dispose (dither runtime)
