module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

let version = "0.1.7"
let title = "fahmiirsyadk"
let description = "FAHMIIRSYADK is a personal/blog website authored by fahmi irsyad khairi"

let head ~children () = 
  H.head [] [
    H.meta [ A.charset2 `UTF8 ] []
    ; H.meta [ A.name "generator"; A.content {j|Dust $version|j} ] []
    ; H.meta [ A.name "viewport "; A.content "width=device-width, initial-scale: 1, shrink-to-fit=no"] []
    ; H.meta [ A.name "title"; A.content title] []
    ; H.meta [ A.name "description"; A.content description] []
    ; E.meta_twitter ~title:title ~description:description ~card:"summary" ()
    ; H.link [ A.rel_link `Stylesheet; A.href "/assets/css/styles.css" ] []
    ; children
  ]