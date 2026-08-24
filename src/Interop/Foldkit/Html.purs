module Interop.Foldkit.Html where

import Interop.Foldkit (Child, Prop, element)
import Interop.Foldkit as Foldkit

elementWithTag :: forall message. String -> Array (Prop message) -> Array (Child message) -> Child message
elementWithTag tag attributes children = element { tag, attributes, children }

a :: forall message. Array (Prop message) -> Array (Child message) -> Child message
a = elementWithTag "a"

article :: forall message. Array (Prop message) -> Array (Child message) -> Child message
article = elementWithTag "article"

button :: forall message. Array (Prop message) -> Array (Child message) -> Child message
button = elementWithTag "button"

canvas :: forall message. Array (Prop message) -> Array (Child message) -> Child message
canvas = elementWithTag "canvas"

code :: forall message. Array (Prop message) -> Array (Child message) -> Child message
code = elementWithTag "code"

div :: forall message. Array (Prop message) -> Array (Child message) -> Child message
div = elementWithTag "div"

footer :: forall message. Array (Prop message) -> Array (Child message) -> Child message
footer = elementWithTag "footer"

header :: forall message. Array (Prop message) -> Array (Child message) -> Child message
header = elementWithTag "header"

h1 :: forall message. Array (Prop message) -> Array (Child message) -> Child message
h1 = elementWithTag "h1"

img :: forall message. Array (Prop message) -> Array (Child message) -> Child message
img = elementWithTag "img"

video :: forall message. Array (Prop message) -> Array (Child message) -> Child message
video = elementWithTag "video"

nav :: forall message. Array (Prop message) -> Array (Child message) -> Child message
nav = elementWithTag "nav"

main :: forall message. Array (Prop message) -> Array (Child message) -> Child message
main = elementWithTag "main"

p :: forall message. Array (Prop message) -> Array (Child message) -> Child message
p = elementWithTag "p"

pre :: forall message. Array (Prop message) -> Array (Child message) -> Child message
pre = elementWithTag "pre"

path :: forall message. Array (Prop message) -> Array (Child message) -> Child message
path = elementWithTag "path"

section :: forall message. Array (Prop message) -> Array (Child message) -> Child message
section = elementWithTag "section"

span :: forall message. Array (Prop message) -> Array (Child message) -> Child message
span = elementWithTag "span"

strong :: forall message. Array (Prop message) -> Array (Child message) -> Child message
strong = elementWithTag "strong"

time :: forall message. Array (Prop message) -> Array (Child message) -> Child message
time = elementWithTag "time"

svg :: forall message. Array (Prop message) -> Array (Child message) -> Child message
svg = elementWithTag "svg"

keyed :: forall message. String -> String -> Array (Prop message) -> Array (Child message) -> Child message
keyed tag key attributes children = Foldkit.keyed { tag, key, attributes, children }

text :: forall message. String -> Child message
text = Foldkit.text
