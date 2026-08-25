module Interop.Foldkit where

import Prelude

import Data.Function.Uncurried (Fn1, Fn2, Fn3, runFn1, runFn2, runFn3)
import Data.Maybe (Maybe(..))
import Interop.Foldkit.Mount (MountAction)

foreign import data HtmlBuilder :: Type -> Type
foreign import data Html :: Type -> Type
foreign import data RenderedProp :: Type -> Type
foreign import data RenderedChild :: Type -> Type

data Prop message
  = Attribute String String
  | InnerHtml String
  | OnClick message
  | OnMouseEnter message
  | OnMouseLeave message
  | OnMount (MountAction message)

data Child message
  = Empty
  | Text String
  | Element
      { tag :: String
      , key :: Maybe String
      , attributes :: Array (Prop message)
      , children :: Array (Child message)
      }
  | Submodel (SubmodelNode message)

foreign import data SubmodelNode :: Type -> Type

type AttributeInput =
  { key :: String
  , value :: String
  }

type ElementInput message =
  { tag :: String
  , attributes :: Array (Prop message)
  , children :: Array (Child message)
  }

type KeyedInput message =
  { tag :: String
  , key :: String
  , attributes :: Array (Prop message)
  , children :: Array (Child message)
  }

type RenderedElementInput message =
  { tag :: String
  , attributes :: Array (RenderedProp message)
  , children :: Array (RenderedChild message)
  }

type RenderedKeyedInput message =
  { tag :: String
  , key :: String
  , attributes :: Array (RenderedProp message)
  , children :: Array (RenderedChild message)
  }

type RenderInput message =
  { builder :: HtmlBuilder message
  , child :: Child message
  }

type SubmodelInput model childMessage parentMessage =
  { slotId :: String
  , model :: model
  , child :: Child childMessage
  , toParentMessage :: childMessage -> parentMessage
  }

type SubmodelNodeInput model childMessage parentMessage =
  { slotId :: String
  , model :: model
  , child :: Child childMessage
  , toParentMessage :: childMessage -> parentMessage
  , renderChild :: HtmlBuilder childMessage -> Child childMessage -> RenderedChild childMessage
  }

foreign import attributeImpl :: forall message. Fn3 (HtmlBuilder message) String String (RenderedProp message)
foreign import emptyImpl :: forall message. Fn1 (HtmlBuilder message) (RenderedChild message)
foreign import elementImpl :: forall message. Fn2 (HtmlBuilder message) (RenderedElementInput message) (RenderedChild message)
foreign import innerHtmlImpl :: forall message. Fn2 (HtmlBuilder message) String (RenderedProp message)
foreign import keyedImpl :: forall message. Fn2 (HtmlBuilder message) (RenderedKeyedInput message) (RenderedChild message)
foreign import onClickImpl :: forall message. Fn2 (HtmlBuilder message) message (RenderedProp message)
foreign import onMouseEnterImpl :: forall message. Fn2 (HtmlBuilder message) message (RenderedProp message)
foreign import onMouseLeaveImpl :: forall message. Fn2 (HtmlBuilder message) message (RenderedProp message)
foreign import onMountImpl :: forall message. Fn2 (HtmlBuilder message) (MountAction message) (RenderedProp message)
foreign import submodelNodeImpl :: forall model childMessage parentMessage. Fn1 (SubmodelNodeInput model childMessage parentMessage) (SubmodelNode parentMessage)
foreign import renderSubmodelImpl :: forall message. Fn2 (HtmlBuilder message) (SubmodelNode message) (RenderedChild message)
foreign import rootImpl :: forall message. Fn1 (RenderedChild message) (Html message)
foreign import textImpl :: forall message. Fn1 String (RenderedChild message)

submodel :: forall model childMessage parentMessage. SubmodelInput model childMessage parentMessage -> Child parentMessage
submodel input = Submodel (runFn1 submodelNodeImpl
  { slotId: input.slotId
  , model: input.model
  , child: input.child
  , toParentMessage: input.toParentMessage
  , renderChild
  })

attribute :: forall message. AttributeInput -> Prop message
attribute input = Attribute input.key input.value

empty :: forall message. Child message
empty = Empty

element :: forall message. ElementInput message -> Child message
element input = Element
  { tag: input.tag
  , key: Nothing
  , attributes: input.attributes
  , children: input.children
  }

innerHtml :: forall message. String -> Prop message
innerHtml = InnerHtml

keyed :: forall message. KeyedInput message -> Child message
keyed input = Element
  { tag: input.tag
  , key: Just input.key
  , attributes: input.attributes
  , children: input.children
  }

onClick :: forall message. message -> Prop message
onClick = OnClick

onMouseEnter :: forall message. message -> Prop message
onMouseEnter = OnMouseEnter

onMouseLeave :: forall message. message -> Prop message
onMouseLeave = OnMouseLeave

onMount :: forall message. MountAction message -> Prop message
onMount = OnMount

text :: forall message. String -> Child message
text = Text

renderProp :: forall message. HtmlBuilder message -> Prop message -> RenderedProp message
renderProp builder prop = case prop of
  Attribute key value -> runFn3 attributeImpl builder key value
  InnerHtml value -> runFn2 innerHtmlImpl builder value
  OnClick message -> runFn2 onClickImpl builder message
  OnMouseEnter message -> runFn2 onMouseEnterImpl builder message
  OnMouseLeave message -> runFn2 onMouseLeaveImpl builder message
  OnMount action -> runFn2 onMountImpl builder action

renderChild :: forall message. HtmlBuilder message -> Child message -> RenderedChild message
renderChild builder child = case child of
  Empty -> runFn1 emptyImpl builder
  Text value -> runFn1 textImpl value
  Element node ->
    let attributes = map (renderProp builder) node.attributes
        children = map (renderChild builder) node.children
    in case node.key of
      Nothing -> runFn2 elementImpl builder
        { tag: node.tag
        , attributes
        , children
        }
      Just key -> runFn2 keyedImpl builder
        { tag: node.tag
        , key
        , attributes
        , children
        }
  Submodel node -> runFn2 renderSubmodelImpl builder node

render :: forall message. RenderInput message -> Html message
render input = runFn1 rootImpl (renderChild input.builder input.child)
