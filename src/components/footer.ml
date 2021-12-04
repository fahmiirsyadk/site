module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let renderYear = 
  Js.Date.now () 
  |> Js.Date.fromFloat 
  |> Js.Date.getFullYear 
  |> Js.Float.toString

let tooltip = A.custom_attr("data-tooltip")
let elem = 
  H.footer [ A.class_ "text-center text-gray-500 py-4"; tooltip "(*) mean Dust static site generator"] (H.text {j| Built with * - $renderYear |j})