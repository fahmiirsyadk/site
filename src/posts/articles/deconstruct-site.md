---
title: "Deconstruct the site"
caption: "Breakdown what's going on behind"
---


Making personal website is hard

Crafting personal website is hard



## Teknis

![symbol](/assets/images/deathSymbol.png#center)


I use my own static site generator tools named Dust. It might be different like other SSG out there.
It's use Rescript as the main compiler, more simple explanation is Dust use Ocaml Syntax as the template engine
and Rescript translate it to plain javascript, like Typescript but extra step. Template engine i make almost all inspired by Halogen from Haskell.


i'm gonna explain every part of it.
### Template Engine

```
module Html = {
  module Elements = {
    open Internal__Dust_Syntax_Compiler

    let text = (node: string) => list{node}
    let a = (attrs, children) => Paired->render("a", attrs, children)
    let abbr = (attrs, children) => Paired->render("abbr", attrs, children)
    let address = (attrs, children) => Paired->render("address", attrs, children)
    let area = (attrs, children) => Paired->render("area", attrs, children)
    ...
  }
  
  module Attributes = {
    ...
    let datetime = (p: Js.Date.t) => AttrString("datetime", p->Js.Date.toString)->attrFormat
    let default = p => AttrBool("default", p)->attrFormat
    let defer = p => AttrBool("defer", p)->attrFormat
    let dir = p => {
      let toString = switch p {
      | #Ltr => "ltr"
      | #Rtl => "rtl"
      | #Auto => "auto"
      }
      AttrString("dir", toString)->attrFormat
    }
    ...     
  }
}
```

```haskell
article :: forall w i. KeyedNode I.HTMLarticle w i
article = keyed (ElemName "article")

article_ :: forall w i. Array (Tuple String (HTML w i)) -> HTML w i
article_ = article []

colgroup :: forall w i. KeyedNode I.HTMLcolgroup w i
colgroup = keyed (ElemName "colgroup")

posInSet :: forall r i. String -> IProp r i
posInSet = attr (AttrName "aria-posinset")

pressed :: forall r i. String -> IProp r i
pressed = attr (AttrName "aria-pressed")

readOnly :: forall r i. String -> IProp r i
readOnly = attr (AttrName "aria-readonly")
```