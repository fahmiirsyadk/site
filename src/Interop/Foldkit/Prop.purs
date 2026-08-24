module Interop.Foldkit.Prop where

import Interop.Foldkit (Prop, attribute)
import Interop.Foldkit as FK
import Interop.Foldkit.Mount (MountAction)

attr :: forall message. String -> String -> Prop message
attr key value = attribute { key, value }

class_ :: forall message. String -> Prop message
class_ = attr "class"

innerHtml :: forall message. String -> Prop message
innerHtml = FK.innerHtml

onClick :: forall message. { message :: message } -> Prop message
onClick input = FK.onClick input.message

onMouseEnter :: forall message. { message :: message } -> Prop message
onMouseEnter input = FK.onMouseEnter input.message

onMouseLeave :: forall message. { message :: message } -> Prop message
onMouseLeave input = FK.onMouseLeave input.message

onMount :: forall message. { action :: MountAction message } -> Prop message
onMount input = FK.onMount input.action
