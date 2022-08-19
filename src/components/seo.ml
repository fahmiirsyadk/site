module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

let version = Dust.Extras.getVersion()
let title = "fahmiirsyadk"
let description = "FAHMIIRSYADK is a personal/blog website authored by fahmi irsyad khairi"
let as_type = A.custom_attr("as")
let cross_origin = A.custom_attr("crossOrigin")

(** 
  * just showing loop
  * same result as
  * ; H.meta [ A.name "generator"; A.content {j|Dust $version|j} ] []
    ; H.meta [ A.name "viewport "; A.content "width=device-width, initial-scale: 1, shrink-to-fit=no"] []
    ; H.meta [ A.name "title"; A.content title] []
    ; H.meta [ A.name "description"; A.content description] []
*)
let meta_info = [
    ("generator", {j|Dust $version|j})
  ; ("author", "fahmi irsyad khairi")
  ; ("description", description)
  ; ("title", title)
] |> Utils.combine_elem (fun a b -> H.meta [ A.name a; A.content b] [])

let font_links = [
    ("/assets/fonts/JetBrainsMono-Regular.woff2", "font/woff2")
  ; ("/assets/fonts/JetBrainsMono-Italic.woff2", "font/woff2")
  ; ("/assets/fonts/JetBrainsMono-Medium.woff2", "font/woff2")
  ; ("/assets/fonts/JetBrainsMono-Bold.woff2", "font/woff2")
  (* ; ("/assets/fonts/SwearBanner-BoldItalic.otf", "font/otf") *)
  (* ; ("/assets/fonts/SwearBanner-MediumItalic.otf", "font/otf") *)
] |> Utils.combine_elem (fun a b -> H.link [ A.rel_link `Preload; as_type "font"; A.href a; cross_origin ""; A.type_ b] [])

let head ~children () =
  let elements = [
    H.title [] (H.text title)
    ; meta_info
    ; H.meta [ A.charset2 `UTF8 ] []
    ; H.meta [ A.name "viewport"; A.content "width=device-width,initial-scale=1,viewport-fit=cover"] []
    ; E.meta_twitter ~title:title ~description:description ~card:"summary" ()
    ; font_links
    ; H.link [ A.rel_link `Preload; A.href "/assets/css/fonts.css"; as_type "style" ] [] 
    ; H.link [ A.rel_link `Stylesheet; A.href "/assets/css/fonts.css" ] [] 
    ; H.link [ A.rel_link `Stylesheet; A.href "/assets/css/styles.css" ] []
    ; H.link [ A.rel_link `Icon; A.type_ "image/png"; A.sizes "16x16"; A.href "/assets/images/16x16.png" ] []
    ; H.link [ A.rel_link `Icon; A.type_ "image/png"; A.sizes "32x32"; A.href "/assets/images/32x32.png" ] []
  ] in
  H.head [] (List.append elements children)