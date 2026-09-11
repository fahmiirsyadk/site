-- | Scheduling policy independent of the browser and of any simulation.
module Site.FrameLoop
  ( FrameMode (..), FrameDriver (..), FrameLoop, newFrameLoop
  , invalidate, cancel, setVisible, dispose
  ) where

import Control.Monad (when)
import Data.IORef
import Data.Maybe (isNothing)

data FrameMode = Continuous | OnDemand deriving (Show, Eq)

data FrameDriver = FrameDriver
  { requestFrame :: IO Int
  , cancelFrame :: Int -> IO ()
  }

data State = State
  { alive :: Bool
  , visible :: Bool
  , pending :: Maybe Int
  }

data FrameLoop = FrameLoop (IORef State) FrameDriver

-- | The driver installs one callback for the lifetime of the loop. A demand
-- invalidation coalesces with an already pending frame; hiding cancels it.
newFrameLoop
  :: FrameMode
  -> ((Double -> IO ()) -> IO FrameDriver)
  -> (Double -> IO ())
  -> IO FrameLoop
newFrameLoop mode install draw = do
  state <- newIORef (State True False Nothing)
  driverRef <- newIORef Nothing
  driver <- install $ \timestamp -> do
    current <- readIORef state
    writeIORef state current { pending = Nothing }
    when (alive current && visible current) $ do
      draw timestamp
      when (mode == Continuous) $ do
        installed <- readIORef driverRef
        mapM_ (invalidate . FrameLoop state) installed
  writeIORef driverRef (Just driver)
  pure (FrameLoop state driver)

invalidate :: FrameLoop -> IO ()
invalidate (FrameLoop state driver) = do
  current <- readIORef state
  when (alive current && visible current && isNothing (pending current)) $ do
    handle <- requestFrame driver
    modifyIORef' state (\value -> value { pending = Just handle })

-- | Drop the pending frame, if any, without changing the loop's availability.
-- The next 'invalidate' re-arms it.
cancel :: FrameLoop -> IO ()
cancel (FrameLoop state driver) = cancelPending state driver

setVisible :: FrameLoop -> Bool -> IO ()
setVisible loop@(FrameLoop state driver) value = do
  current <- readIORef state
  writeIORef state current { visible = value }
  if value then invalidate loop else cancelPending state driver

dispose :: FrameLoop -> IO ()
dispose (FrameLoop state driver) = do
  modifyIORef' state (\value -> value { alive = False, visible = False })
  cancelPending state driver

cancelPending :: IORef State -> FrameDriver -> IO ()
cancelPending state driver = do
  handle <- atomicModifyIORef' state (\value -> (value { pending = Nothing }, pending value))
  mapM_ (cancelFrame driver) handle
