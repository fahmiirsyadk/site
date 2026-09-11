-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecursiveDo #-}
-----------------------------------------------------------------------------
-- | The random scribble, ported from the source's @RandomScribble.purs@ and
-- @RandomScribble.ts@. The variant choice and the play loop live here in
-- Haskell; the Web Animations API only draws one cycle at a time.
--
-- The loop is chained from the animation's @onfinish@: stage a variant,
-- measure it, animate it, and on finish stage the next. Reduced motion
-- stages a single static variant instead.
module Site.Widgets.Scribble
  ( mount
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
  , Function (..)
  , freeFunction
  , create
  , fromJSValUnchecked
  , jsg
  , jsNull
  , setField
  , syncCallback1
  , toJSVal
  , (!)
  , (#)
  )
import           Miso.String (MisoString, ms)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Platform (prefersReducedMotion)
import           Site.Scribble
import           Site.Widgets.Gl (isAbsent)
import qualified Site.Widgets.Browser as Browser
-----------------------------------------------------------------------------
data Live = Live
  { livePath         :: JSVal
  , livePrevious     :: IORef Int
  , liveDisposed     :: IORef Bool
  , liveAnimation    :: IORef JSVal
  , liveReduceMotion :: Bool
  , liveOnFinish     :: JSVal
  }
-----------------------------------------------------------------------------
mount :: Browser.Scope -> JSVal -> IO Bool
mount scope container = do
  path <- container # "querySelector" $ Config.scribblePathSelector
  absent <- isAbsent path
  unless absent (mountPath scope path)
  pure True

mountPath :: Browser.Scope -> JSVal -> IO ()
mountPath scope path = mdo
  reduceMotion <- prefersReducedMotion
  previous <- newIORef (-1)
  disposed <- newIORef False
  animation <- newIORef jsNull
  callback <- syncCallback1 (\_ -> playNext live)
  let live = Live
        { livePath = path
        , livePrevious = previous
        , liveDisposed = disposed
        , liveAnimation = animation
        , liveReduceMotion = reduceMotion
        , liveOnFinish = callback
        }
  hidePath path
  Browser.own scope $ do
    dispose live
    freeFunction (Function callback)
  if reduceMotion
    then void (stageVariant live)
    else playNext live
-----------------------------------------------------------------------------
-- | Cancel the running cycle and stop the chain from staging another.
dispose :: Live -> IO ()
dispose live = do
  writeIORef (liveDisposed live) True
  animation <- readIORef (liveAnimation live)
  absent <- isAbsent animation
  unless absent $ do
    setField animation "onfinish" jsNull
    void $ animation # "cancel" $ ()
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
  setField animation "onfinish" (liveOnFinish live)
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
