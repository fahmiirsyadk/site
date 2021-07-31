open Mana_core
open Utils

module Extra = {
  let inject = (path: string) =>
    Fs_Extra.readFileSync(
      Node.Path.join([
        Node.Process.cwd(),
        path->Js.String2.split(Node.Path.sep)->Node.Path.join,
      ])->Node.Path.normalize,
      "utf-8",
    )

  type extractType =
    | CSS(string)
    | JS(string)

  let extract = (path: extractType) => {
    switch path {
    | CSS(path) => inject(path)
    | JS(path) => inject(path)
    }
  }
}

module Property = {
  type nameAttrs =
    | Keyword
    | Description
    | Author
    | Viewport
    | ApplicationName
    | Generator
    | ThemeColor
  
  %%private(
    let nameAttrsToString = (attr) => 
      switch attr {
            | Keyword => "keyword"
            | Description => "description"
            | Author => "author"
            | Viewport => "viewport"
            | ApplicationName => "application-name"
            | Generator => "generator"
            | ThemeColor => "theme-color"
            }
  )
  let title = (prop: string) => "title"->textAttr(prop)
  let selected = (prop: bool) => "selected"->boolAttr(prop)
  let hidden = (prop: bool) => "hidden"->boolAttr(prop)
  let value = (prop: string) => "value"->textAttr(prop)
  let defaultValue = (prop: string) => "defaultValue"->textAttr(prop)
  let accept = (prop: string) => "accept"->textAttr(prop)
  let acceptCharset = (prop: string) => "acceptCharset"->textAttr(prop)
  let autocomplete = (prop: bool) => "autocomplete"->boolAttr(prop)
  let action = (prop: string) => "action"->textAttr(prop)
  let autosave = (prop: string) => "autosave"->textAttr(prop)
  let disabled = (prop: bool) => "disabled"->boolAttr(prop)
  let enctype = (prop: string) => "enctype"->textAttr(prop)
  let formation = (prop: string) => "formation"->textAttr(prop)
  let list_ = (prop: string) => "list"->textAttr(prop)
  let maxlength = (prop: string) => "maxlength"->textAttr(prop)
  let minlength = (prop: string) => "minlength"->textAttr(prop)
  let method__ = (prop: string) => "method"->textAttr(prop)
  let multiple = (prop: bool) => "multiple"->boolAttr(prop)
  let novalidate = (prop: bool) => "novalidate"->boolAttr(prop)
  let pattern = (prop: string) => "pattern"->textAttr(prop)
  let readonly = (prop: bool) => "readonly"->boolAttr(prop)
  let required = (prop: bool) => "required"->boolAttr(prop)
  let size = (prop: string) => "size"->textAttr(prop)
  let sizes = (prop: string) => "sizes"->textAttr(prop)
  let for_ = (prop: string) => "for_"->textAttr(prop)
  let form = (prop: string) => "form"->textAttr(prop)
  let max = (prop: string) => "max"->textAttr(prop)
  let min = (prop: string) => "min"->textAttr(prop)
  let step = (prop: string) => "step"->textAttr(prop)
  let cols = (prop: string) => "cols"->textAttr(prop)
  let rows = (prop: string) => "rows"->textAttr(prop)
  let wrap = (prop: string) => "wrap"->textAttr(prop)
  let target = (prop: string) => "target"->textAttr(prop)
  let download = (prop: string) => "download"->textAttr(prop)
  let downloadAs = (prop: string) => "downloadAs"->textAttr(prop)
  let hreflang = (prop: string) => "hreflang"->textAttr(prop)
  let media = (prop: string) => "media"->textAttr(prop)
  let ping = (prop: string) => "ping"->textAttr(prop)
  let rel = (prop: string) => "rel"->textAttr(prop)
  let ismap = (prop: string) => "ismap"->textAttr(prop)
  let usemap = (prop: string) => "usemap"->textAttr(prop)
  let shape = (prop: string) => "shape"->textAttr(prop)
  let src = (prop: string) => "src"->textAttr(prop)
  let heigth = (prop: string) => "heigth"->textAttr(prop)
  let width = (prop: string) => "width"->textAttr(prop)
  let alt = (prop: string) => "alt"->textAttr(prop)
  let autoplay = (prop: bool) => "autoplay"->boolAttr(prop)
  let controls = (prop: bool) => "controls"->boolAttr(prop)
  let loop = (prop: bool) => "loop"->boolAttr(prop)
  let preload = (prop: string) => "preload"->textAttr(prop)
  let poster = (prop: string) => "poster"->textAttr(prop)
  let default = (prop: bool) => "default"->boolAttr(prop)
  let kind = (prop: string) => "kind"->textAttr(prop)
  let srclang = (prop: string) => "srclang"->textAttr(prop)
  let sandbox = (prop: string) => "sandbox"->textAttr(prop)
  let seamless = (prop: string) => "seamless"->textAttr(prop)
  let srcdoc = (prop: string) => "srcdoc"->textAttr(prop)
  let style = (prop: string) => "style"->textAttr(prop)
  let reversed = (prop: string) => "reversed"->textAttr(prop)
  let start = (prop: string) => "start"->textAttr(prop)
  let align = (prop: string) => "align"->textAttr(prop)
  let colspan = (prop: string) => "colspan"->textAttr(prop)
  let rowspan = (prop: string) => "rowspan"->textAttr(prop)
  let headers = (prop: string) => "headers"->textAttr(prop)
  let scope = (prop: string) => "scope"->textAttr(prop)
  let async = (prop: string) => "async"->textAttr(prop)
  let charset = (prop: string) => "charset"->textAttr(prop)
  let content = (prop: string) => "content"->textAttr(prop)
  let defer = (prop: string) => "defer"->textAttr(prop)
  let httpEquiv = (prop: string) => "httpEquiv"->textAttr(prop)
  let lang = (prop: string) => "lang"->textAttr(prop)
  let scoped = (prop: string) => "scoped"->textAttr(prop)
  let type_ = (prop: string) => "type"->textAttr(prop)
  let name = (prop: nameAttrs): string => "name"->textAttr(prop->nameAttrsToString)
  let href = (prop: string) => "href"->textAttr(prop)
  let id = (prop: string) => "id"->textAttr(prop)
  let placeholder = (prop: string) => "placeholder"->textAttr(prop)
  let property = (prop: string) => "property"->textAttr(prop)
  let checked = (prop: bool) => "checked"->boolAttr(prop)
  let autofocus = (prop: bool) => "autofocus"->boolAttr(prop)
  let class_ = (prop: string) => "class"->textAttr(prop)
  let as_ = (prop: string) => "as"->textAttr(prop)
  let crossorigin = (prop: string) => "crossorigin"->textAttr(prop)
}

module HTML = {
  let text = (node: string) => list{node}
  let a = (attrs: list<string>, children: list<string>) => Paired->render("a", attrs, children)
  let abbr = (attrs: list<string>, children: list<string>) =>
    Paired->render("abbr", attrs, children)
  let address = (attrs: list<string>, children: list<string>) =>
    Paired->render("address", attrs, children)
  let area = (attrs: list<string>, children: list<string>) =>
    Paired->render("area", attrs, children)
  let article = (attrs: list<string>, children: list<string>) =>
    Paired->render("article", attrs, children)
  let aside = (attrs: list<string>, children: list<string>) =>
    Paired->render("aside", attrs, children)
  let audio = (attrs: list<string>, children: list<string>) =>
    Paired->render("audio", attrs, children)
  let b = (attrs: list<string>, children: list<string>) => Paired->render("b", attrs, children)
  let base = (attrs: list<string>, children: list<string>) =>
    Paired->render("base", attrs, children)
  let bdi = (attrs: list<string>, children: list<string>) => Paired->render("bdi", attrs, children)
  let bdo = (attrs: list<string>, children: list<string>) => Paired->render("bdo", attrs, children)
  let blockquotes = (attrs: list<string>, children: list<string>) =>
    Paired->render("blockquotes", attrs, children)
  let body = (attrs: list<string>, children: list<string>) =>
    Paired->render("body", attrs, children)
  let br = (attrs: list<string>, children: list<string>) => Paired->render("br", attrs, children)
  let button = (attrs: list<string>, children: list<string>) =>
    Paired->render("button", attrs, children)
  let canvas = (attrs: list<string>, children: list<string>) =>
    Paired->render("canvas", attrs, children)
  let caption = (attrs: list<string>, children: list<string>) =>
    Paired->render("caption", attrs, children)
  let cite = (attrs: list<string>, children: list<string>) =>
    Paired->render("cite", attrs, children)
  let code = (attrs: list<string>, children: list<string>) =>
    Paired->render("code", attrs, children)
  let col = (attrs: list<string>, children: list<string>) => Paired->render("col", attrs, children)
  let colgroup = (attrs: list<string>, children: list<string>) =>
    Paired->render("colgroup", attrs, children)
  let command = (attrs: list<string>, children: list<string>) =>
    Paired->render("command", attrs, children)
  let datalist = (attrs: list<string>, children: list<string>) =>
    Paired->render("datalist", attrs, children)
  let dd = (attrs: list<string>, children: list<string>) => Paired->render("dd", attrs, children)
  let del = (attrs: list<string>, children: list<string>) => Paired->render("del", attrs, children)
  let details = (attrs: list<string>, children: list<string>) =>
    Paired->render("details", attrs, children)
  let dfn = (attrs: list<string>, children: list<string>) => Paired->render("dfn", attrs, children)
  let dialog = (attrs: list<string>, children: list<string>) =>
    Paired->render("dialog", attrs, children)
  let div = (attrs: list<string>, children: list<string>) => Paired->render("div", attrs, children)
  let dl = (attrs: list<string>, children: list<string>) => Paired->render("dl", attrs, children)
  let dt = (attrs: list<string>, children: list<string>) => Paired->render("dt", attrs, children)
  let em = (attrs: list<string>, children: list<string>) => Paired->render("em", attrs, children)
  let embed = (attrs: list<string>, children: list<string>) =>
    Paired->render("embed", attrs, children)
  let figcation = (attrs: list<string>, children: list<string>) =>
    Paired->render("figcation", attrs, children)
  let figure = (attrs: list<string>, children: list<string>) =>
    Paired->render("figure", attrs, children)
  let footer = (attrs: list<string>, children: list<string>) =>
    Paired->render("footer", attrs, children)
  let form = (attrs: list<string>, children: list<string>) =>
    Paired->render("form", attrs, children)
  let h1 = (attrs: list<string>, children: list<string>) => Paired->render("h1", attrs, children)
  let h2 = (attrs: list<string>, children: list<string>) => Paired->render("h2", attrs, children)
  let h3 = (attrs: list<string>, children: list<string>) => Paired->render("h3", attrs, children)
  let h4 = (attrs: list<string>, children: list<string>) => Paired->render("h4", attrs, children)
  let h5 = (attrs: list<string>, children: list<string>) => Paired->render("h5", attrs, children)
  let h6 = (attrs: list<string>, children: list<string>) => Paired->render("h6", attrs, children)
  let head = (attrs: list<string>, children: list<string>) =>
    Paired->render("head", attrs, children)
  let header = (attrs: list<string>, children: list<string>) =>
    Paired->render("header", attrs, children)
  let hr = (attrs: list<string>, children: list<string>) => Paired->render("hr", attrs, children)
  let html = (attrs: list<string>, children: list<string>) =>
    Paired->render("html", attrs, children)
  let i = (attrs: list<string>, children: list<string>) => Paired->render("i", attrs, children)
  let iframe = (attrs: list<string>, children: list<string>) =>
    Paired->render("iframe", attrs, children)
  let img = (attrs: list<string>, children: list<string>) => Single->render("img", attrs, children)
  let input = (attrs: list<string>, children: list<string>) =>
    Single->render("input", attrs, children)
  let ins = (attrs: list<string>, children: list<string>) => Paired->render("ins", attrs, children)
  let kbd = (attrs: list<string>, children: list<string>) => Paired->render("kbd", attrs, children)
  let label = (attrs: list<string>, children: list<string>) =>
    Paired->render("label", attrs, children)
  let legend = (attrs: list<string>, children: list<string>) =>
    Paired->render("legend", attrs, children)
  let li = (attrs: list<string>, children: list<string>) => Paired->render("li", attrs, children)
  let link = (attrs: list<string>, children: list<string>) =>
    Single->render("link", attrs, children)
  let main = (attrs: list<string>, children: list<string>) =>
    Paired->render("main", attrs, children)
  let map = (attrs: list<string>, children: list<string>) => Paired->render("map", attrs, children)
  let mark = (attrs: list<string>, children: list<string>) =>
    Paired->render("mark", attrs, children)
  let menu = (attrs: list<string>, children: list<string>) =>
    Paired->render("menu", attrs, children)
  let menuItem = (attrs: list<string>, children: list<string>) =>
    Paired->render("menuItem", attrs, children)
  let meta = (attrs: list<string>, children: list<string>) =>
    Single->render("meta", attrs, children)
  let meter = (attrs: list<string>, children: list<string>) =>
    Paired->render("meter", attrs, children)
  let nav = (attrs: list<string>, children: list<string>) => Paired->render("nav", attrs, children)
  let noscript = (attrs: list<string>, children: list<string>) =>
    Paired->render("noscript", attrs, children)
  // object is a reserved keyword
  let object_ = (attrs: list<string>, children: list<string>) =>
    Paired->render("object", attrs, children)
  let ul = (attrs: list<string>, children: list<string>) => Paired->render("ul", attrs, children)
  let ol = (attrs: list<string>, children: list<string>) => Paired->render("ol", attrs, children)
  let optgroup = (attrs: list<string>, children: list<string>) =>
    Paired->render("optgroup", attrs, children)
  let p = (attrs: list<string>, children: list<string>) => Paired->render("p", attrs, children)
  let param = (attrs: list<string>, children: list<string>) =>
    Paired->render("param", attrs, children)
  let pre = (attrs: list<string>, children: list<string>) => Paired->render("pre", attrs, children)
  let q = (attrs: list<string>, children: list<string>) => Paired->render("q", attrs, children)
  let rp = (attrs: list<string>, children: list<string>) => Paired->render("rp", attrs, children)
  let rt = (attrs: list<string>, children: list<string>) => Paired->render("rt", attrs, children)
  let ruby = (attrs: list<string>, children: list<string>) =>
    Paired->render("ruby", attrs, children)
  let samp = (attrs: list<string>, children: list<string>) =>
    Paired->render("samp", attrs, children)
  // escape runtime
  let script = (attrs: list<string>, children: list<string>) =>
    Paired->render("script", attrs, children)
  let section = (attrs: list<string>, children: list<string>) =>
    Paired->render("section", attrs, children)
  let select = (attrs: list<string>, children: list<string>) =>
    Paired->render("select", attrs, children)
  let small = (attrs: list<string>, children: list<string>) =>
    Paired->render("small", attrs, children)
  let source = (attrs: list<string>, children: list<string>) =>
    Paired->render("source", attrs, children)
  let span = (attrs: list<string>, children: list<string>) =>
    Paired->render("span", attrs, children)
  let strong = (attrs: list<string>, children: list<string>) =>
    Paired->render("strong", attrs, children)
  let style = (attrs: list<string>, children: list<string>) =>
    Paired->render("style", attrs, children)
  let sub = (attrs: list<string>, children: list<string>) => Paired->render("sub", attrs, children)
  let summary = (attrs: list<string>, children: list<string>) =>
    Paired->render("summary", attrs, children)
  let sup = (attrs: list<string>, children: list<string>) => Paired->render("sup", attrs, children)
  let table = (attrs: list<string>, children: list<string>) =>
    Paired->render("table", attrs, children)
  let tbody = (attrs: list<string>, children: list<string>) =>
    Paired->render("tbody", attrs, children)
  let td = (attrs: list<string>, children: list<string>) => Paired->render("td", attrs, children)
  let textarea = (attrs: list<string>, children: list<string>) =>
    Paired->render("textarea", attrs, children)
  let tfoot = (attrs: list<string>, children: list<string>) =>
    Paired->render("tfoot", attrs, children)
  let th = (attrs: list<string>, children: list<string>) => Paired->render("th", attrs, children)
  let thead = (attrs: list<string>, children: list<string>) =>
    Paired->render("thead", attrs, children)
  let time = (attrs: list<string>, children: list<string>) =>
    Paired->render("time", attrs, children)
  let title = (attrs: list<string>, children: list<string>) =>
    Paired->render("title", attrs, children)
  let tr = (attrs: list<string>, children: list<string>) => Paired->render("tr", attrs, children)
  let track = (attrs: list<string>, children: list<string>) =>
    Paired->render("track", attrs, children)
  let u = (attrs: list<string>, children: list<string>) => Paired->render("u", attrs, children)
  let var = (attrs: list<string>, children: list<string>) => Paired->render("var", attrs, children)
  let video = (attrs: list<string>, children: list<string>) =>
    Paired->render("video", attrs, children)
  let wbr = (attrs: list<string>, children: list<string>) => Paired->render("wbr", attrs, children)
}
