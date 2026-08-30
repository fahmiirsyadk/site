module Platform.Browser.RandomScribble
  ( animateScribble
  , hideScribblePath
  , mountRandomScribble
  , prepareScribblePath
  ) where

import Prelude

import Foldkit.Mount (Element)
import Platform.Browser (Cleanup)
import Platform.Browser.Sensors as Sensors
import PursTs.Effect as Fx
import Runtime.Scribble as Scribble

foreign import hideScribblePath :: Element -> Unit

foreign import prepareScribblePath :: Element -> String -> Boolean -> Number

foreign import animateScribble
  :: Element
  -> Scribble.ScribbleAnimation
  -> Fx.Effect Fx.Never Fx.NoServices Unit
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

type ScribbleState =
  { disposed :: Boolean
  , previousIndex :: Int
  }

type ScribbleContext =
  { path :: Element
  , reduceMotion :: Boolean
  , stateCell :: Sensors.Cell ScribbleState
  , animationCell :: Sensors.Cell Cleanup
  , chainCell :: Sensors.Cell (Fx.Effect Fx.Never Fx.NoServices Unit)
  }

noopCleanup :: Cleanup
noopCleanup = Sensors.composeCleanups []

noAction :: Fx.Effect Fx.Never Fx.NoServices Unit
noAction = Fx.sync \_ -> unit

-- | Endlessly cycles randomly-selected scribble variants (never repeating one
-- | twice in a row); with reduced motion a single static variant is staged.
mountRandomScribble :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountRandomScribble element = do
  pathFound <- Sensors.findElement element "[data-random-scribble-path]"
  case pathFound of
    [] -> pure noopCleanup
    [path] -> mountScribblePath path
    _ -> pure noopCleanup

mountScribblePath :: Element -> Fx.Effect Fx.Never Fx.NoServices Cleanup
mountScribblePath path = do
  reduceMotion <- Sensors.prefersReducedMotion
  stateCell <- Sensors.newCell { disposed: false, previousIndex: -1 }
  animationCell <- Sensors.newCell noopCleanup
  chainCell <- Sensors.newCell noAction
  let context = { path, reduceMotion, stateCell, animationCell, chainCell }
  Fx.sync \_ -> hideScribblePath path
  if reduceMotion then do
    _ <- pickScribbleVariant context
    pure unit
  else do
    Sensors.writeCell chainCell (playScribbleNext context)
    playScribbleNext context
  pure
    (Sensors.composeCleanups
      [ -- Cancel the running cycle first; marking disposed also stops the
        -- finished-continuation from chaining a fresh one.
        Sensors.cleanupOfCell context.animationCell
      , Sensors.cleanupOfEffect (markScribbleDisposed context.stateCell)
      ])

-- | Stages one randomly-selected variant and returns its measured length.
pickScribbleVariant :: ScribbleContext -> Fx.Effect Fx.Never Fx.NoServices Number
pickScribbleVariant context = do
  state <- Sensors.readCell context.stateCell
  random <- Sensors.randomUint32
  let variant = Scribble.selectScribble state.previousIndex (random `mod` Scribble.variantCount)
  Sensors.writeCell context.stateCell state { previousIndex = variant.index }
  Fx.sync \_ -> prepareScribblePath context.path variant.path context.reduceMotion

-- | Plays one animation cycle; the sibling invokes the continuation we hand it
-- when the cycle finishes, which reads the next cycle out of the chain cell.
-- Indirection through the cell keeps playScribbleNext non-recursive —
-- self-recursive functions emit unannotated (circular) TypeScript.
playScribbleNext :: ScribbleContext -> Fx.Effect Fx.Never Fx.NoServices Unit
playScribbleNext context = do
  state <- Sensors.readCell context.stateCell
  if state.disposed || context.reduceMotion then pure unit else do
    pathLength <- pickScribbleVariant context
    cleanup <-
      animateScribble
        context.path
        (Scribble.scribbleAnimation pathLength)
        (resumeScribbleChain context.chainCell)
    Sensors.writeCell context.animationCell cleanup

resumeScribbleChain
  :: Sensors.Cell (Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Unit
resumeScribbleChain chainCell = do
  next <- Sensors.readCell chainCell
  next

markScribbleDisposed :: Sensors.Cell ScribbleState -> Fx.Effect Fx.Never Fx.NoServices Unit
markScribbleDisposed stateCell = do
  state <- Sensors.readCell stateCell
  Sensors.writeCell stateCell state { disposed = true }
