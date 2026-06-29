{-# LANGUAGE OverloadedStrings #-}
module Dev
  ( devServer
  ) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Exception (SomeException, try)
import Control.Monad (forever, void, when)
import Data.IORef (atomicModifyIORef', newIORef, writeIORef)
import Development.Shake (Rules, ShakeOptions, shake)
import Network.Wai.Application.Static (defaultFileServerSettings, staticApp)
import Network.Wai.Handler.Warp (run)
import System.FSNotify (withManager, watchTree)

devServer :: Int -> FilePath -> [FilePath] -> ShakeOptions -> Rules () -> IO ()
devServer port serveDir watchDirs shOpts rules = do
  putStrLn $ "Serving " ++ serveDir ++ " at http://localhost:" ++ show port
  putStrLn $ "Watching: " ++ unwords watchDirs
  putStrLn "NOTE: Haskell source (src/, app/) changes need a server restart"
  putStrLn "      to recompile the binary; this watcher only rebuilds content/assets."
  putStrLn "Press Ctrl-C to stop."
  void $ forkIO $ run port $ staticApp $ defaultFileServerSettings serveDir
  runBuild
  changed <- newIORef False
  let flag _ = writeIORef changed True
  withManager $ \mgr -> do
    mapM_ (\d -> watchTree mgr d (const True) flag) watchDirs
    forever $ do
      threadDelay 300000
      c <- atomicModifyIORef' changed (\x -> (False, x))
      when c runBuild
  where
    runBuild :: IO ()
    runBuild = do
      putStrLn "Rebuilding site..."
      result <- try (void $ shake shOpts rules) :: IO (Either SomeException ())
      case result of
        Left e  -> putStrLn $ "Rebuild error: " ++ show e
        Right _ -> putStrLn "Rebuild complete."