module Interop.Foldkit.Mount where

import Data.Function.Uncurried (Fn1, Fn2, mkFn1, runFn2)

foreign import data MountAction :: Type -> Type

foreign import ditheredImage :: forall message. MountAction message
foreign import hollowMark :: forall message. MountAction message
foreign import randomScribble :: forall message. MountAction message
foreign import seaShader :: forall message. MountAction message
foreign import mapMessageImpl :: forall message nextMessage. Fn2 (MountAction message) (Fn1 message nextMessage) (MountAction nextMessage)

mapMessage :: forall message nextMessage. MountAction message -> (message -> nextMessage) -> MountAction nextMessage
mapMessage action f = runFn2 mapMessageImpl action (mkFn1 f)
