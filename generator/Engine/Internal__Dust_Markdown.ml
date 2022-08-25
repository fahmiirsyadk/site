type 'a markdownConfig = {
  html: bool;
  highlight: string -> 'a -> string;
}

type 'a h = {
  codeToHtml: (string -> 'a -> string);
}

type t

type matterResult = {
  content: string
}

external markdownIt: 'a markdownConfig -> t = "markdown-it" [@@bs.new] [@@bs.module]
external render: t -> string -> string = "render" [@@bs.send]
external getHighlighter: 'a -> 'b h Promise.t = "getHighlighter" [@@bs.module "shiki"]
external matter: string -> matterResult = "gray-matter" [@@bs.module]
external parseJson: string -> 'a = "parse" [@@bs.scope "JSON"] [@@bs.val]


let renderMarkdown raw =
  let matter = raw |> matter in
  let theme = 
    (Node.Path.join2 Internal__Dust_Config.rootPath Internal__Dust_Config.config.syntaxThemeUrl)
    |> Node.Path.normalize
    |> Node.Fs.readFileAsUtf8Sync
    |> parseJson 
  in
  [%bs.obj { theme }] 
  |> getHighlighter
  |> Js.Promise.then_ (fun h -> 
      let md = markdownIt {
        html = true;
        highlight =
          (fun code -> 
            fun lang -> (h.codeToHtml code [%bs.obj { lang }]))
      } in
      [%bs.obj {
        matter;
        html = md 
        |. render (matter.content)
        |. Node.Buffer.fromString
        |. Node.Buffer.toString
      }] |> Promise.resolve
    )
