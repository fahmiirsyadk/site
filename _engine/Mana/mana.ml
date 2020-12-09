open Mana_core.Core
module Property =
struct
  let title (prop : string) =
    ((("title")[@reason.raw_literal "title"]) |. textAttr) prop
  let selected (prop : bool) =
    ((("selected")[@reason.raw_literal "selected"]) |. boolAttr) prop
  let hidden (prop : bool) =
    ((("hidden")[@reason.raw_literal "hidden"]) |. boolAttr) prop
  let value (prop : string) =
    ((("value")[@reason.raw_literal "value"]) |. textAttr) prop
  let defaultValue (prop : string) =
    ((("defaultValue")[@reason.raw_literal "defaultValue"]) |. textAttr)
      prop
  let accept (prop : string) =
    ((("accept")[@reason.raw_literal "accept"]) |. textAttr) prop
  let acceptCharset (prop : string) =
    ((("acceptCharset")[@reason.raw_literal "acceptCharset"]) |. textAttr)
      prop
  let autocomplete (prop : bool) =
    ((("autocomplete")[@reason.raw_literal "autocomplete"]) |. boolAttr)
      prop
  let action (prop : string) =
    ((("action")[@reason.raw_literal "action"]) |. textAttr) prop
  let autosave (prop : string) =
    ((("autosave")[@reason.raw_literal "autosave"]) |. textAttr) prop
  let disabled (prop : bool) =
    ((("disabled")[@reason.raw_literal "disabled"]) |. boolAttr) prop
  let enctype (prop : string) =
    ((("enctype")[@reason.raw_literal "enctype"]) |. textAttr) prop
  let formation (prop : string) =
    ((("formation")[@reason.raw_literal "formation"]) |. textAttr) prop
  let list (prop : string) =
    ((("list")[@reason.raw_literal "list"]) |. textAttr) prop
  let maxlength (prop : string) =
    ((("maxlength")[@reason.raw_literal "maxlength"]) |. textAttr) prop
  let minlength (prop : string) =
    ((("minlength")[@reason.raw_literal "minlength"]) |. textAttr) prop
  let method__ (prop : string) =
    ((("method")[@reason.raw_literal "method"]) |. textAttr) prop
  let multiple (prop : bool) =
    ((("multiple")[@reason.raw_literal "multiple"]) |. boolAttr) prop
  let novalidate (prop : bool) =
    ((("novalidate")[@reason.raw_literal "novalidate"]) |. boolAttr) prop
  let pattern (prop : string) =
    ((("pattern")[@reason.raw_literal "pattern"]) |. textAttr) prop
  let readonly (prop : bool) =
    ((("readonly")[@reason.raw_literal "readonly"]) |. boolAttr) prop
  let required (prop : bool) =
    ((("required")[@reason.raw_literal "required"]) |. boolAttr) prop
  let size (prop : string) =
    ((("size")[@reason.raw_literal "size"]) |. textAttr) prop
  let for_ (prop : string) =
    ((("for_")[@reason.raw_literal "for_"]) |. textAttr) prop
  let form (prop : string) =
    ((("form")[@reason.raw_literal "form"]) |. textAttr) prop
  let max (prop : string) =
    ((("max")[@reason.raw_literal "max"]) |. textAttr) prop
  let min (prop : string) =
    ((("min")[@reason.raw_literal "min"]) |. textAttr) prop
  let step (prop : string) =
    ((("step")[@reason.raw_literal "step"]) |. textAttr) prop
  let cols (prop : string) =
    ((("cols")[@reason.raw_literal "cols"]) |. textAttr) prop
  let rows (prop : string) =
    ((("rows")[@reason.raw_literal "rows"]) |. textAttr) prop
  let wrap (prop : string) =
    ((("wrap")[@reason.raw_literal "wrap"]) |. textAttr) prop
  let target (prop : string) =
    ((("target")[@reason.raw_literal "target"]) |. textAttr) prop
  let download (prop : string) =
    ((("download")[@reason.raw_literal "download"]) |. textAttr) prop
  let downloadAs (prop : string) =
    ((("downloadAs")[@reason.raw_literal "downloadAs"]) |. textAttr) prop
  let hreflang (prop : string) =
    ((("hreflang")[@reason.raw_literal "hreflang"]) |. textAttr) prop
  let media (prop : string) =
    ((("media")[@reason.raw_literal "media"]) |. textAttr) prop
  let ping (prop : string) =
    ((("ping")[@reason.raw_literal "ping"]) |. textAttr) prop
  let rel (prop : string) =
    ((("rel")[@reason.raw_literal "rel"]) |. textAttr) prop
  let ismap (prop : string) =
    ((("ismap")[@reason.raw_literal "ismap"]) |. textAttr) prop
  let usemap (prop : string) =
    ((("usemap")[@reason.raw_literal "usemap"]) |. textAttr) prop
  let shape (prop : string) =
    ((("shape")[@reason.raw_literal "shape"]) |. textAttr) prop
  let src (prop : string) =
    ((("src")[@reason.raw_literal "src"]) |. textAttr) prop
  let heigth (prop : string) =
    ((("heigth")[@reason.raw_literal "heigth"]) |. textAttr) prop
  let width (prop : string) =
    ((("width")[@reason.raw_literal "width"]) |. textAttr) prop
  let alt (prop : string) =
    ((("alt")[@reason.raw_literal "alt"]) |. textAttr) prop
  let autoplay (prop : bool) =
    ((("autoplay")[@reason.raw_literal "autoplay"]) |. boolAttr) prop
  let controls (prop : bool) =
    ((("controls")[@reason.raw_literal "controls"]) |. boolAttr) prop
  let loop (prop : bool) =
    ((("loop")[@reason.raw_literal "loop"]) |. boolAttr) prop
  let preload (prop : string) =
    ((("preload")[@reason.raw_literal "preload"]) |. textAttr) prop
  let poster (prop : string) =
    ((("poster")[@reason.raw_literal "poster"]) |. textAttr) prop
  let default (prop : bool) =
    ((("default")[@reason.raw_literal "default"]) |. boolAttr) prop
  let kind (prop : string) =
    ((("kind")[@reason.raw_literal "kind"]) |. textAttr) prop
  let srclang (prop : string) =
    ((("srclang")[@reason.raw_literal "srclang"]) |. textAttr) prop
  let sandbox (prop : string) =
    ((("sandbox")[@reason.raw_literal "sandbox"]) |. textAttr) prop
  let seamless (prop : string) =
    ((("seamless")[@reason.raw_literal "seamless"]) |. textAttr) prop
  let srcdoc (prop : string) =
    ((("srcdoc")[@reason.raw_literal "srcdoc"]) |. textAttr) prop
  let style (prop : string) =
    ((("style")[@reason.raw_literal "style"]) |. textAttr) prop
  let reversed (prop : string) =
    ((("reversed")[@reason.raw_literal "reversed"]) |. textAttr) prop
  let start (prop : string) =
    ((("start")[@reason.raw_literal "start"]) |. textAttr) prop
  let align (prop : string) =
    ((("align")[@reason.raw_literal "align"]) |. textAttr) prop
  let colspan (prop : string) =
    ((("colspan")[@reason.raw_literal "colspan"]) |. textAttr) prop
  let rowspan (prop : string) =
    ((("rowspan")[@reason.raw_literal "rowspan"]) |. textAttr) prop
  let headers (prop : string) =
    ((("headers")[@reason.raw_literal "headers"]) |. textAttr) prop
  let scope (prop : string) =
    ((("scope")[@reason.raw_literal "scope"]) |. textAttr) prop
  let async (prop : string) =
    ((("async")[@reason.raw_literal "async"]) |. textAttr) prop
  let charset (prop : string) =
    ((("charset")[@reason.raw_literal "charset"]) |. textAttr) prop
  let content (prop : string) =
    ((("content")[@reason.raw_literal "content"]) |. textAttr) prop
  let defer (prop : string) =
    ((("defer")[@reason.raw_literal "defer"]) |. textAttr) prop
  let httpEquiv (prop : string) =
    ((("httpEquiv")[@reason.raw_literal "httpEquiv"]) |. textAttr) prop
  let language (prop : string) =
    ((("language")[@reason.raw_literal "language"]) |. textAttr) prop
  let scoped (prop : string) =
    ((("scoped")[@reason.raw_literal "scoped"]) |. textAttr) prop
  let type_ (prop : string) =
    ((("type")[@reason.raw_literal "type"]) |. textAttr) prop
  let name (prop : string) =
    ((("name")[@reason.raw_literal "name"]) |. textAttr) prop
  let href (prop : string) =
    ((("href")[@reason.raw_literal "href"]) |. textAttr) prop
  let id (prop : string) =
    ((("id")[@reason.raw_literal "id"]) |. textAttr) prop
  let placeholder (prop : string) =
    ((("placeholder")[@reason.raw_literal "placeholder"]) |. textAttr) prop
  let property (prop : string) =
    ((("property")[@reason.raw_literal "property"]) |. textAttr) prop
  let checked (prop : bool) =
    ((("checked")[@reason.raw_literal "checked"]) |. boolAttr) prop
  let autofocus (prop : bool) =
    ((("autofocus")[@reason.raw_literal "autofocus"]) |. boolAttr) prop
  let class_ (prop : string) =
    ((("class")[@reason.raw_literal "class"]) |. textAttr) prop
end
module HTML =
struct
  let text (node : string) = [node]
  let a (attrs : string list) (children : string list) =
    render (("a")[@reason.raw_literal "a"]) attrs children
  let abbr (attrs : string list) (children : string list) =
    render (("abbr")[@reason.raw_literal "abbr"]) attrs children
  let address (attrs : string list) (children : string list) =
    render (("address")[@reason.raw_literal "address"]) attrs children
  let area (attrs : string list) (children : string list) =
    render (("area")[@reason.raw_literal "area"]) attrs children
  let article (attrs : string list) (children : string list) =
    render (("article")[@reason.raw_literal "article"]) attrs children
  let aside (attrs : string list) (children : string list) =
    render (("aside")[@reason.raw_literal "aside"]) attrs children
  let audio (attrs : string list) (children : string list) =
    render (("audio")[@reason.raw_literal "audio"]) attrs children
  let b (attrs : string list) (children : string list) =
    render (("b")[@reason.raw_literal "b"]) attrs children
  let base (attrs : string list) (children : string list) =
    render (("base")[@reason.raw_literal "base"]) attrs children
  let bdi (attrs : string list) (children : string list) =
    render (("bdi")[@reason.raw_literal "bdi"]) attrs children
  let bdo (attrs : string list) (children : string list) =
    render (("bdo")[@reason.raw_literal "bdo"]) attrs children
  let blockquotes (attrs : string list) (children : string list) =
    render (("blockquotes")[@reason.raw_literal "blockquotes"]) attrs
      children
  let body (attrs : string list) (children : string list) =
    render (("body")[@reason.raw_literal "body"]) attrs children
  let br (attrs : string list) (children : string list) =
    render (("br")[@reason.raw_literal "br"]) attrs children
  let button (attrs : string list) (children : string list) =
    render (("button")[@reason.raw_literal "button"]) attrs children
  let canvas (attrs : string list) (children : string list) =
    render (("canvas")[@reason.raw_literal "canvas"]) attrs children
  let caption (attrs : string list) (children : string list) =
    render (("caption")[@reason.raw_literal "caption"]) attrs children
  let cite (attrs : string list) (children : string list) =
    render (("cite")[@reason.raw_literal "cite"]) attrs children
  let code (attrs : string list) (children : string list) =
    render (("code")[@reason.raw_literal "code"]) attrs children
  let col (attrs : string list) (children : string list) =
    render (("col")[@reason.raw_literal "col"]) attrs children
  let colgroup (attrs : string list) (children : string list) =
    render (("colgroup")[@reason.raw_literal "colgroup"]) attrs children
  let command (attrs : string list) (children : string list) =
    render (("command")[@reason.raw_literal "command"]) attrs children
  let datalist (attrs : string list) (children : string list) =
    render (("datalist")[@reason.raw_literal "datalist"]) attrs children
  let dd (attrs : string list) (children : string list) =
    render (("dd")[@reason.raw_literal "dd"]) attrs children
  let del (attrs : string list) (children : string list) =
    render (("del")[@reason.raw_literal "del"]) attrs children
  let details (attrs : string list) (children : string list) =
    render (("details")[@reason.raw_literal "details"]) attrs children
  let dfn (attrs : string list) (children : string list) =
    render (("dfn")[@reason.raw_literal "dfn"]) attrs children
  let dialog (attrs : string list) (children : string list) =
    render (("dialog")[@reason.raw_literal "dialog"]) attrs children
  let div (attrs : string list) (children : string list) =
    render (("div")[@reason.raw_literal "div"]) attrs children
  let dl (attrs : string list) (children : string list) =
    render (("dl")[@reason.raw_literal "dl"]) attrs children
  let dt (attrs : string list) (children : string list) =
    render (("dt")[@reason.raw_literal "dt"]) attrs children
  let em (attrs : string list) (children : string list) =
    render (("em")[@reason.raw_literal "em"]) attrs children
  let embed (attrs : string list) (children : string list) =
    render (("embed")[@reason.raw_literal "embed"]) attrs children
  let figcation (attrs : string list) (children : string list) =
    render (("figcation")[@reason.raw_literal "figcation"]) attrs children
  let figure (attrs : string list) (children : string list) =
    render (("figure")[@reason.raw_literal "figure"]) attrs children
  let footer (attrs : string list) (children : string list) =
    render (("footer")[@reason.raw_literal "footer"]) attrs children
  let form (attrs : string list) (children : string list) =
    render (("form")[@reason.raw_literal "form"]) attrs children
  let h1 (attrs : string list) (children : string list) =
    render (("h1")[@reason.raw_literal "h1"]) attrs children
  let h2 (attrs : string list) (children : string list) =
    render (("h2")[@reason.raw_literal "h2"]) attrs children
  let h3 (attrs : string list) (children : string list) =
    render (("h3")[@reason.raw_literal "h3"]) attrs children
  let h4 (attrs : string list) (children : string list) =
    render (("h4")[@reason.raw_literal "h4"]) attrs children
  let h5 (attrs : string list) (children : string list) =
    render (("h5")[@reason.raw_literal "h5"]) attrs children
  let h6 (attrs : string list) (children : string list) =
    render (("h6")[@reason.raw_literal "h6"]) attrs children
  let head (attrs : string list) (children : string list) =
    render (("head")[@reason.raw_literal "head"]) attrs children
  let header (attrs : string list) (children : string list) =
    render (("header")[@reason.raw_literal "header"]) attrs children
  let hr (attrs : string list) (children : string list) =
    render (("hr")[@reason.raw_literal "hr"]) attrs children
  let html (attrs : string list) (children : string list) =
    render (("html")[@reason.raw_literal "html"]) attrs children
  let i (attrs : string list) (children : string list) =
    render (("i")[@reason.raw_literal "i"]) attrs children
  let iframe (attrs : string list) (children : string list) =
    render (("iframe")[@reason.raw_literal "iframe"]) attrs children
  let img (attrs : string list) (children : string list) =
    render (("img")[@reason.raw_literal "img"]) attrs children
  let input (attrs : string list) (children : string list) =
    render (("input")[@reason.raw_literal "input"]) attrs children
  let ins (attrs : string list) (children : string list) =
    render (("ins")[@reason.raw_literal "ins"]) attrs children
  let kbd (attrs : string list) (children : string list) =
    render (("kbd")[@reason.raw_literal "kbd"]) attrs children
  let label (attrs : string list) (children : string list) =
    render (("label")[@reason.raw_literal "label"]) attrs children
  let legend (attrs : string list) (children : string list) =
    render (("legend")[@reason.raw_literal "legend"]) attrs children
  let li (attrs : string list) (children : string list) =
    render (("li")[@reason.raw_literal "li"]) attrs children
  let link (attrs : string list) (children : string list) =
    render (("link")[@reason.raw_literal "link"]) attrs children
  let main (attrs : string list) (children : string list) =
    render (("main")[@reason.raw_literal "main"]) attrs children
  let map (attrs : string list) (children : string list) =
    render (("map")[@reason.raw_literal "map"]) attrs children
  let mark (attrs : string list) (children : string list) =
    render (("mark")[@reason.raw_literal "mark"]) attrs children
  let menu (attrs : string list) (children : string list) =
    render (("menu")[@reason.raw_literal "menu"]) attrs children
  let menuItem (attrs : string list) (children : string list) =
    render (("menuItem")[@reason.raw_literal "menuItem"]) attrs children
  let meta (attrs : string list) (children : string list) =
    render (("meta")[@reason.raw_literal "meta"]) attrs children
  let meter (attrs : string list) (children : string list) =
    render (("meter")[@reason.raw_literal "meter"]) attrs children
  let nav (attrs : string list) (children : string list) =
    render (("nav")[@reason.raw_literal "nav"]) attrs children
  let noscript (attrs : string list) (children : string list) =
    render (("noscript")[@reason.raw_literal "noscript"]) attrs children
  let object_ (attrs : string list) (children : string list) =
    render (("object")[@reason.raw_literal "object"]) attrs children
  let ol (attrs : string list) (children : string list) =
    render (("ol")[@reason.raw_literal "ol"]) attrs children
  let optgroup (attrs : string list) (children : string list) =
    render (("optgroup")[@reason.raw_literal "optgroup"]) attrs children
  let p (attrs : string list) (children : string list) =
    render (("p")[@reason.raw_literal "p"]) attrs children
  let param (attrs : string list) (children : string list) =
    render (("param")[@reason.raw_literal "param"]) attrs children
  let pre (attrs : string list) (children : string list) =
    render (("pre")[@reason.raw_literal "pre"]) attrs children
  let q (attrs : string list) (children : string list) =
    render (("q")[@reason.raw_literal "q"]) attrs children
  let rp (attrs : string list) (children : string list) =
    render (("rp")[@reason.raw_literal "rp"]) attrs children
  let rt (attrs : string list) (children : string list) =
    render (("rt")[@reason.raw_literal "rt"]) attrs children
  let ruby (attrs : string list) (children : string list) =
    render (("ruby")[@reason.raw_literal "ruby"]) attrs children
  let samp (attrs : string list) (children : string list) =
    render (("samp")[@reason.raw_literal "samp"]) attrs children
  let script (attrs : string list) (children : string list) =
    render (("script")[@reason.raw_literal "script"]) attrs children
  let section (attrs : string list) (children : string list) =
    render (("section")[@reason.raw_literal "section"]) attrs children
  let select (attrs : string list) (children : string list) =
    render (("select")[@reason.raw_literal "select"]) attrs children
  let small (attrs : string list) (children : string list) =
    render (("small")[@reason.raw_literal "small"]) attrs children
  let source (attrs : string list) (children : string list) =
    render (("source")[@reason.raw_literal "source"]) attrs children
  let span (attrs : string list) (children : string list) =
    render (("span")[@reason.raw_literal "span"]) attrs children
  let strong (attrs : string list) (children : string list) =
    render (("strong")[@reason.raw_literal "strong"]) attrs children
  let style (attrs : string list) (children : string list) =
    render (("style")[@reason.raw_literal "style"]) attrs children
  let sub (attrs : string list) (children : string list) =
    render (("sub")[@reason.raw_literal "sub"]) attrs children
  let summary (attrs : string list) (children : string list) =
    render (("summary")[@reason.raw_literal "summary"]) attrs children
  let sup (attrs : string list) (children : string list) =
    render (("sup")[@reason.raw_literal "sup"]) attrs children
  let table (attrs : string list) (children : string list) =
    render (("table")[@reason.raw_literal "table"]) attrs children
  let tbody (attrs : string list) (children : string list) =
    render (("tbody")[@reason.raw_literal "tbody"]) attrs children
  let td (attrs : string list) (children : string list) =
    render (("td")[@reason.raw_literal "td"]) attrs children
  let textarea (attrs : string list) (children : string list) =
    render (("textarea")[@reason.raw_literal "textarea"]) attrs children
  let tfoot (attrs : string list) (children : string list) =
    render (("tfoot")[@reason.raw_literal "tfoot"]) attrs children
  let th (attrs : string list) (children : string list) =
    render (("th")[@reason.raw_literal "th"]) attrs children
  let thead (attrs : string list) (children : string list) =
    render (("thead")[@reason.raw_literal "thead"]) attrs children
  let time (attrs : string list) (children : string list) =
    render (("time")[@reason.raw_literal "time"]) attrs children
  let title (attrs : string list) (children : string list) =
    render (("title")[@reason.raw_literal "title"]) attrs children
  let tr (attrs : string list) (children : string list) =
    render (("tr")[@reason.raw_literal "tr"]) attrs children
  let track (attrs : string list) (children : string list) =
    render (("track")[@reason.raw_literal "track"]) attrs children
  let u (attrs : string list) (children : string list) =
    render (("u")[@reason.raw_literal "u"]) attrs children
  let var (attrs : string list) (children : string list) =
    render (("var")[@reason.raw_literal "var"]) attrs children
  let video (attrs : string list) (children : string list) =
    render (("video")[@reason.raw_literal "video"]) attrs children
  let wbr (attrs : string list) (children : string list) =
    render (("wbr")[@reason.raw_literal "wbr"]) attrs children
end
