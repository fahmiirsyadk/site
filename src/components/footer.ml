module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let renderYear = 
  Js.Date.now () 
  |> Js.Date.fromFloat 
  |> Js.Date.getFullYear 
  |> Js.Float.toString

let dustver = Dust.Extras.getVersion()
let renderTime = Js.Date.now() |> Js.Date.fromFloat |> Js.Date.toUTCString

let tooltip = A.custom_attr("data-tooltip")
let elem = 
  H.footer [ A.class_ "py-4 bottom-0" ] [
    H.p [ A.class_ "text-center text-zinc-500 text-xs"; tooltip "(*) mean Dust static site generator" ] (H.text {j| Built with Dust $dustver | <b> $renderYear </b> |j})
    ; H.p [ A.class_ "text-center text-zinc-500 text-xs"; tooltip "(*) mean Dust static site generator" ] (H.text {j| last render: $renderTime |j})
  ]