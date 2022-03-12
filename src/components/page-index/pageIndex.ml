module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

let title = "Genesis"
let desc = ""

(** ARTICLES BLOG LISTS *)
type matter = { title : string }

type metadata =
  { name : string
  ; layout : string
  ; source : string
  ; data : matter
  ; excerpt : string
  ; url : string
  ; content : string
  }

type posts = { blog : metadata array; projects : metadata array }

let articleLinks list = list |. Belt.List.map (fun post ->
  H.article [ A.class_ "mt-8"] [
    H.h3 [ A.class_ "font-medium text-md"] [
      H.a [ A.href post.url] (H.text post.data.title)
    ]
  ; H.p [] (H.text "excerpt coming soon")
  ]
)

let sections id data_list =
  let emptyContents elem = 
    match data_list |> List.length with
    | 0 -> H.text "No post yet."
    | _ -> elem
  in
  H.div [ A.class_ "flex-1"] [
    H.h2 [ A.class_ "font-swear italic mb-4 font-medium text-gray-800 text-2xl"] (H.text id)
  ; H.div [] (emptyContents (articleLinks data_list))
  ]

let header =
  H.header [ A.class_ "text-center"] [
    H.div [
      A.class_ "position-absolute left-0 top-0 w-100 h-64"
    ; Aria.ariaHidden "true"
    ] []
  ; H.h1 [ A.class_ "font-bold font-swear text-3xl mb-8 text-gray-900"] (H.text "Fahmi Irsyad Khairi")
  ; H.p [ A.class_ "px-32 sm:px-32 md:px-64 lg:px-64 text-gray-600 font-medium"] (H.text desc)
  ]

let threeJS = 
  H.script [ A.type_ "module"] (H.text (E.inject "js/three.js"))