module Platform.Effect
  ( Milliseconds(..)
  , bracket
  , delay
  , throwError
  , try
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Function.Uncurried (runFn3)
import PursTs.Effect as Fx

newtype Milliseconds = Milliseconds Int

derive instance eqMilliseconds :: Eq Milliseconds

derive instance ordMilliseconds :: Ord Milliseconds

delay :: Milliseconds -> Fx.Effect Fx.Never Fx.NoServices Unit
delay (Milliseconds n) = Fx.sleepMilliseconds n

throwError :: forall error value. error -> Fx.Effect error Fx.NoServices value
throwError = Fx.fail

try
  :: forall error value
   . Fx.Effect error Fx.NoServices value
  -> Fx.Effect Fx.Never Fx.NoServices (Either error value)
try effect = Fx.match effect { onFailure: Left, onSuccess: Right }

bracket
  :: forall error resource value
   . Fx.Effect error Fx.NoServices resource
  -> (resource -> Unit)
  -> (resource -> Fx.Effect error Fx.NoServices value)
  -> Fx.Effect error Fx.NoServices value
bracket = runFn3 Fx.bracket
