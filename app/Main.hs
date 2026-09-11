-----------------------------------------------------------------------------
{-# LANGUAGE CPP #-}
-----------------------------------------------------------------------------
-- | Entry point, and nothing else. The application lives in 'Site.App'.
module Main (main) where
-----------------------------------------------------------------------------
#ifdef INTERACTIVE
import           Miso (reload)
#else
import           Miso (miso)
#endif
-----------------------------------------------------------------------------
import           Site.App (app, bootModel, siteEvents)
import qualified Site.Platform as Platform
-----------------------------------------------------------------------------
#ifdef WASM
#ifndef INTERACTIVE
foreign export javascript "hs_start" main :: IO ()
#endif
#endif
-----------------------------------------------------------------------------
main :: IO ()
main = do
  initial <- bootModel
  Platform.installInternalLinkGuard
#ifdef INTERACTIVE
  -- The interactive browser watches an empty page: draw.
  reload siteEvents (app initial)
#else
  -- Production loads a prerendered page and hydrates it, falling back to a
  -- draw when the markup is absent (for example a bare `make build`).
  miso siteEvents (\_ -> app initial)
#endif
-----------------------------------------------------------------------------
