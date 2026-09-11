-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The random scribble, ported from the source's @RandomScribble.purs@ and
-- @RandomScribble.ts@. The variant choice and the play loop live here in
-- Haskell; the Web Animations API only draws one cycle at a time.
--
-- The loop is chained from the animation's @onfinish@: stage a variant,
-- measure it, animate it, and on finish stage the next. Reduced motion
-- stages a single static variant instead.
module Site.Widgets.Scribble
  ( attach
  , dispose
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (unless, void)
import           Data.IORef
  ( IORef
  , newIORef
  , readIORef
  , writeIORef
  )
import           Miso.DSL
  ( JSVal
  , create
  , fromJSValUnchecked
  , isNull
  , isUndefined
  , jsg
  , jsNull
  , setField
  , syncCallback1
  , toJSVal
  , (!)
  , (#)
  )
import           Miso.String (MisoString, ms)
import           System.IO.Unsafe (unsafePerformIO)
-----------------------------------------------------------------------------
import           Site.Platform (prefersReducedMotion)
import           Site.Scribble
-----------------------------------------------------------------------------
data Live = Live
  { livePath         :: JSVal
  , livePrevious     :: IORef Int
  , liveDisposed     :: IORef Bool
  , liveAnimation    :: IORef JSVal
  , liveReduceMotion :: Bool
  }
-----------------------------------------------------------------------------
scribbleRef :: IORef (Maybe Live)
scribbleRef = unsafePerformIO (newIORef Nothing)
{-# NOINLINE scribbleRef #-}
-----------------------------------------------------------------------------
-- | Mount the scribble if its span is in the document. Idempotent.
attach :: IO ()
attach = do
  current <- readIORef scribbleRef
  case current of
    Just _  -> pure ()
    Nothing -> do
      document <- jsg "document"
      container <- document # "querySelector" $ ("[data-random-scribble]" :: MisoString)
      containerAbsent <- isAbsent container
      unless containerAbsent $ do
        path <- container # "querySelector" $ ("[data-random-scribble-path]" :: MisoString)
        pathAbsent <- isAbsent path
        unless pathAbsent (mount path)
-----------------------------------------------------------------------------
mount :: JSVal -> IO ()
mount path = do
  reduceMotion <- prefersReducedMotion
  previous <- newIORef (-1)
  disposed <- newIORef False
  animation <- newIORef jsNull
  let live = Live
        { livePath = path
        , livePrevious = previous
        , liveDisposed = disposed
        , liveAnimation = animation
        , liveReduceMotion = reduceMotion
        }
  hidePath path
  writeIORef scribbleRef (Just live)
  if reduceMotion
    then void (stageVariant live)
    else playNext live
-----------------------------------------------------------------------------
-- | Cancel the running cycle and stop the chain from staging another.
dispose :: IO ()
dispose = do
  current <- readIORef scribbleRef
  case current of
    Nothing   -> pure ()
    Just live -> do
      writeIORef (liveDisposed live) True
      animation <- readIORef (liveAnimation live)
      absent <- isAbsent animation
      unless absent $ void $ animation # "cancel" $ ()
      writeIORef scribbleRef Nothing
-----------------------------------------------------------------------------
hidePath :: JSVal -> IO ()
hidePath path = do
  style <- path ! "style"
  setField style "visibility" ("hidden" :: MisoString)
-----------------------------------------------------------------------------
-- | Stage one variant on the path and return its measured length.
stageVariant :: Live -> IO Double
stageVariant live = do
  random <- mathRandom
  previousIndex <- readIORef (livePrevious live)
  let candidate = floor (random * fromIntegral scribbleVariantCount)
      index = selectScribble previousIndex candidate
  writeIORef (livePrevious live) index
  let path = livePath live
  void $ path # "setAttribute" $ ("d" :: MisoString, scribblePathAt index)
  lengthValue <- path # "getTotalLength" $ ()
  pathLength <- fromJSValUnchecked lengthValue
  let dash = ms (show pathLength)
  style <- path ! "style"
  setField style "strokeDasharray" (dash <> " " <> dash)
  setField style "strokeDashoffset"
    (if liveReduceMotion live then "0" else dash)
  setField style "visibility" ("visible" :: MisoString)
  pure pathLength
-----------------------------------------------------------------------------
-- | Play one cycle; @onfinish@ chains the next.
playNext :: Live -> IO ()
playNext live = do
  disposed <- readIORef (liveDisposed live)
  unless disposed $ do
    pathLength <- stageVariant live
    animation <- animate live pathLength
    writeIORef (liveAnimation live) animation
-----------------------------------------------------------------------------
animate :: Live -> Double -> IO JSVal
animate live pathLength = do
  frames <- mapM frameObject (animationFrames plan)
  framesValue <- toJSVal frames
  options <- create
  setField options "duration" (animationDuration plan)
  setField options "easing" (animationEasing plan)
  setField options "fill" (animationFill plan)
  animation <- livePath live # "animate" $ (framesValue, options)
  callback <- syncCallback1 $ \_ -> playNext live
  setField animation "onfinish" callback
  pure animation
  where
    plan = scribbleAnimation pathLength
    frameObject frame = do
      object <- create
      setField object "strokeDashoffset" (ms (show (frameDashOffset frame)))
      setField object "offset" (frameOffset frame)
      pure object
-----------------------------------------------------------------------------
mathRandom :: IO Double
mathRandom = do
  math <- jsg "Math"
  value <- math # "random" $ ()
  fromJSValUnchecked value
-----------------------------------------------------------------------------
isAbsent :: JSVal -> IO Bool
isAbsent value = (||) <$> isNull value <*> isUndefined value
