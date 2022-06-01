module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let renderYear = 
  Js.Date.now () 
  |> Js.Date.fromFloat 
  |> Js.Date.getFullYear 
  |> Js.Float.toString

let dustver = Dust.Extras.getVersion()
let renderTime = Js.Date.now() |> Js.Date.fromFloat |> Js.Date.toUTCString

let styles = [%bs.obj {
  text = A.class_ "text-center text-zinc-300 text-xs";
  textLink = A.class_ "text-zinc-200 underline underline-offset-2 font-medium hover:underline-offset-4"
}]

let elem ~source ~fixed = 
  let fixedToStyle = if fixed then "absolute" else "relative" in
  H.footer [ A.class_ ({j| py-4 w-full bottom-0 $fixedToStyle |j}) ] [
    H.p [ styles##text ] (H.text {j| Built with Dust $dustver | <b> $renderYear </b>|j})
    ; H.p [ styles##text ] (H.text {j| last render: $renderTime |j})
    ; H.div [ A.class_ "mt-4" ] []
    ; H.p [ styles##text ] [
        H.a [ styles##textLink; A.href source ] [ "Source code" ]
      ]
  ]