module Interop.Foldkit.Mount where

foreign import data MountAction :: Type -> Type

foreign import ditheredImage :: forall message. MountAction message
foreign import hollowMark :: forall message. MountAction message
foreign import randomScribble :: forall message. MountAction message
foreign import seaShader :: forall message. MountAction message
