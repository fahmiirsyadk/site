module Platform.Browser.Sensors
  ( Bounds
  , Cell
  , ChildListDelta
  , PointerSample
  , clientSize
  , cleanupOfCell
  , cleanupOfEffect
  , composeCleanups
  , computedStyleValue
  , devicePixelRatio
  , elementBounds
  , elementsEqual
  , findElement
  , forEach
  , imageComplete
  , imageNaturalSize
  , isDarkTheme
  , matchesSelector
  , newCell
  , nowTimestamp
  , observeChildList
  , observeDataAttribute
  , observeResize
  , observeTheme
  , observeVisibility
  , onContextLost
  , onImageLoad
  , onPointer
  , onWindowResize
  , parentElement
  , prefersReducedMotion
  , randomUint32
  , readCell
  , readDataAttribute
  , runCleanup
  , selectElements
  , setAspectRatio
  , startLoop
  , writeCell
  , writeDataFlag
  ) where

import Prelude

import Foldkit.Mount (Element)
import Platform.Browser (Cleanup)
import PursTs.Effect as Fx

type Bounds = { width :: Number, height :: Number }

type PointerSample =
  { kind :: String
  , x :: Number
  , y :: Number
  , pointerId :: Number
  }

type ChildListDelta = { added :: Array Element, removed :: Array Element }

foreign import data Cell :: Type -> Type

foreign import newCell :: forall a. a -> Fx.Effect Fx.Never Fx.NoServices (Cell a)
foreign import readCell :: forall a. Cell a -> Fx.Effect Fx.Never Fx.NoServices a
foreign import writeCell
  :: forall a
   . Cell a
  -> a
  -> Fx.Effect Fx.Never Fx.NoServices Unit

foreign import composeCleanups :: Array Cleanup -> Cleanup
foreign import runCleanup :: Cleanup -> Fx.Effect Fx.Never Fx.NoServices Unit

-- | A cleanup that reads the cell when invoked, so a restartable resource (an
-- | animation loop) is always torn down in its latest incarnation.
foreign import cleanupOfCell :: Cell Cleanup -> Cleanup

-- | Turns an effect into a one-shot cleanup action.
foreign import cleanupOfEffect
  :: Fx.Effect Fx.Never Fx.NoServices Unit
  -> Cleanup

-- | Runs a tick every animation frame. The tick returns false to stop
-- | scheduling; a fresh loop may be started later.
foreign import startLoop
  :: (Number -> Fx.Effect Fx.Never Fx.NoServices Boolean)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import onPointer
  :: Element
  -> { capture :: Boolean, preventDefault :: Boolean }
  -> (PointerSample -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import observeResize
  :: Element
  -> (Bounds -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import observeTheme
  :: (Boolean -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import observeVisibility
  :: Number
  -> Element
  -> (Boolean -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import observeDataAttribute
  :: Element
  -> String
  -> (String -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import observeChildList
  :: Element
  -> (ChildListDelta -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import onImageLoad
  :: Element
  -> Fx.Effect Fx.Never Fx.NoServices Unit
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import onContextLost
  :: Element
  -> Fx.Effect Fx.Never Fx.NoServices Unit
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import onWindowResize
  :: Fx.Effect Fx.Never Fx.NoServices Unit
  -> Fx.Effect Fx.Never Fx.NoServices Cleanup

foreign import prefersReducedMotion :: Fx.Effect Fx.Never Fx.NoServices Boolean
foreign import isDarkTheme :: Fx.Effect Fx.Never Fx.NoServices Boolean
foreign import devicePixelRatio :: Fx.Effect Fx.Never Fx.NoServices Number
foreign import nowTimestamp :: Fx.Effect Fx.Never Fx.NoServices Number
foreign import randomUint32 :: Fx.Effect Fx.Never Fx.NoServices Int
foreign import elementBounds :: Element -> Fx.Effect Fx.Never Fx.NoServices Bounds
foreign import clientSize :: Element -> Fx.Effect Fx.Never Fx.NoServices Bounds
foreign import imageNaturalSize :: Element -> Fx.Effect Fx.Never Fx.NoServices Bounds
foreign import imageComplete :: Element -> Fx.Effect Fx.Never Fx.NoServices Boolean
foreign import matchesSelector :: Element -> String -> Fx.Effect Fx.Never Fx.NoServices Boolean
foreign import findElement :: Element -> String -> Fx.Effect Fx.Never Fx.NoServices (Array Element)
foreign import selectElements :: Element -> String -> Fx.Effect Fx.Never Fx.NoServices (Array Element)
foreign import parentElement :: Element -> Fx.Effect Fx.Never Fx.NoServices (Array Element)
foreign import elementsEqual :: Element -> Element -> Boolean

-- | Effectful iteration without Data.Foldable's class dictionaries, which the
-- | backend cannot type in generated TypeScript.
foreign import forEach
  :: forall a
   . Array a
  -> (a -> Fx.Effect Fx.Never Fx.NoServices Unit)
  -> Fx.Effect Fx.Never Fx.NoServices Unit
foreign import readDataAttribute :: Element -> String -> Fx.Effect Fx.Never Fx.NoServices String
foreign import writeDataFlag
  :: Element
  -> String
  -> Boolean
  -> Fx.Effect Fx.Never Fx.NoServices Unit
foreign import setAspectRatio
  :: Element
  -> Number
  -> Number
  -> Fx.Effect Fx.Never Fx.NoServices Unit
foreign import computedStyleValue :: Element -> String -> Fx.Effect Fx.Never Fx.NoServices String
