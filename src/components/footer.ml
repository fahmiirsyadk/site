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
  H.footer [] [
    H.p [ A.class_ "text-center text-gray-500 py-4"; tooltip "(*) mean Dust static site generator" ] (H.text {j| Built with Dust $dustver | <b> $renderYear </b> |j})
    ; H.p [ A.class_ "text-center text-gray-500 py-4 text-xs"; tooltip "(*) mean Dust static site generator" ] (H.text {j| last render: $renderTime |j})
  ]