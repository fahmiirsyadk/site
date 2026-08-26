module Platform.Browser.Scroll where

import Prelude

import Data.Function.Uncurried (Fn1, Fn3, Fn4, mkFn1, runFn3, runFn4)
import Foldkit.Mount (MountAction)
import Foldkit.Mount as Mount
import PursTs.Effect as Fx
import Runtime.Scroll as Runtime

type Tracker =
  { scrollRootSelector :: String
  , layoutSelector :: String
  , contentSelector :: String
  , headingSelector :: String
  }

foreign import trackReadingStreamImpl
  :: forall row message
   . Fn4
       Mount.Element
       { | row }
       (Fn1 Runtime.Geometry message)
       (Fn1 String message)
       (Mount.Stream message)

foreign import scrollToHeadingImpl
  :: Fn3 String String Boolean (Fx.Effect Fx.Never Fx.NoServices Unit)

foreign import scrollToProgressImpl
  :: Fn3 String Int Boolean (Fx.Effect Fx.Never Fx.NoServices Unit)

trackReadingProgress
  :: forall message
   . String
  -> Tracker
  -> (String -> message)
  -> (Runtime.Geometry -> message)
  -> MountAction message
trackReadingProgress name tracker onFailure onChanged =
  Mount.defineStreamWith name tracker \captured element ->
    runFn4 trackReadingStreamImpl element captured (mkFn1 onChanged) (mkFn1 onFailure)

scrollToHeading
  :: String -> String -> Boolean -> Fx.Effect Fx.Never Fx.NoServices Unit
scrollToHeading = runFn3 scrollToHeadingImpl

scrollToProgress
  :: String -> Int -> Boolean -> Fx.Effect Fx.Never Fx.NoServices Unit
scrollToProgress = runFn3 scrollToProgressImpl
