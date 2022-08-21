module H = Dust.Html.Elements
module A = Dust.Html.Attributes

type caption = 
| None
| Some of string

type dataPost = { title : string; caption: caption }

type post =
  { content : string
  ; data : dataPost
  ; name : string
  ; layout : string
  ; source : string
  ; excerpt : string
  ; url : string
  ; page: string
  }

let markdownStyle = H.style [] [
  {|
    img[src*="#center"] {
      display: block;
      margin: auto;
    }
    .sidenote {
      font-size: 14px; 
      width: 224px;
      height: 0;
    }
    @media(max-width: 1200px) {
      .sidenote {
        transform: translate(0, 0) !important;
        width: auto;
        height: auto;
      }
    }
  |}
]

let as_type = A.custom_attr("as")
let cross_origin = A.custom_attr("crossOrigin")
let font_swear = [
    ("/assets/fonts/SwearBanner-BoldItalic.otf", "font/otf")
  ; ("/assets/fonts/SwearBanner-MediumItalic.otf", "font/otf")
] |> Utils.combineElement2 (fun a b -> H.link [ A.rel_link `Preload; as_type "font"; A.href a; cross_origin ""; A.type_ b] [])

let footer =
  let renderYear = 
    Js.Date.now () 
    |> Js.Date.fromFloat 
    |> Js.Date.getFullYear 
    |> Js.Float.toString
  in
  let dustver = Dust.Extras.getVersion() in
  let renderTime = Js.Date.now() |> Js.Date.fromFloat |> Js.Date.toUTCString in
  let flower1 pos =
    H.pre [ A.class_ {j|text-sm absolute bottom-0 $pos|j}] [
      H.code [ A.class_ "block font-sans text-orange-600 font-bold" ] [ "***" ]
    ; H.code [ A.class_ "block font-sans text-orange-600 font-bold" ] [ "***" ]
    ; H.code [ A.class_ "block font-sans" ] [ " |" ]
    ; H.code [ A.class_ "block font-sans" ] [ " |" ]
    ] in
  let flower2 pos =
    H.pre [ A.class_ {j|text-sm absolute bottom-0 $pos|j} ] [
      H.code [ A.class_ "block font-sans" ] [ " " ]
    ; H.code [ A.class_ "block font-sans" ] [ " " ]
    ; H.code [ A.class_ "block font-sans text-orange-600 font-bold" ] [ {|@|} ]
    ; H.code [ A.class_ "block font-sans" ] [ {|||} ]
    ] in
  H.footer [ A.class_ "relative h-64 bg-neutral-100" ] [
    H.div [ A.class_ "text-xs absolute z-0 bottom-2 text-neutral-600 w-full text-center" ] [
      {j|fa-h $renderYear | Dust $dustver at $renderTime |j}
    ]
  ;  flower2 "right-14"
  ; flower1 "right-56"
  ; flower2 "right-64"
  ; flower1 "left-14"
  ; flower2 "right-32"
  ; flower1 "right-20"
  ; flower2 "left-56"
  ]

let main post =
  (* let _ = 
   match post.content |> Syntax.getString with
   | Some content -> Js.log content
   | None -> Js.log "no content"
in *)
  (* let _ =
    match post.content |> Syntax.splitCodeBlock with
    | Some _ -> Js.log "has"
    | None -> Js.log "no codeblock"
in *)
  let caption = 
    match post.data.caption with
    | Some(data) -> data
    | None -> ""
in
  let filterUrl = if post.name == "blog" then "articles" else post.name
in
  let selectedIsBlog = if post.name == "blog" then "text-orange-400" else "hover:text-orange-400"
in
  let selectedIsProjects = if post.name == "projects" then "text-orange-400" else "hover:text-orange-400"
in
  (* let url = (Node.Path.join2 filterUrl (post.page |> Node.Path.basename))
  |> Node.Path.normalize  *)
(* in *)
  H.html [ A.lang "en" ] [
    Seo.head ~children: [ markdownStyle; font_swear ] ()
  ; H.body [ A.class_ "bg-neutral-100 antialised" ] [
      (* H.header [ A.class_ "w-full select-none h-20 fixed top-0 text-neutral-400 flex items-center justify-center"; ] [
        H.nav [ A.class_ "flex items-center content-center"; ] [
          H.div [ A.class_ "space-x-6" ] [
            H.a [ A.href "/blog"; A.class_ {j|font-medium cursor-pointer $selectedIsBlog|j} ] [ "Blog" ]
          ; H.a [ A.href "/projects"; A.class_ {j|font-medium cursor-pointer $selectedIsProjects|j} ] [ "Projects" ]
          ]
        ; H.div [ A.class_ "mx-6 ease-in-out duration-300 hover:rotate-[120deg] cursor-pointer" ] [
            H.a [ A.href "/" ] [
              Logo.logoRatio 30 "#f5f5f5"
            ]
          ]
        ; H.div [ A.class_ "space-x-6" ] [
            H.a [ A.href "/about"; A.class_ "font-medium hover:text-neutral-50 cursor-pointer" ] [ "About" ]
          ; H.a [ A.href "/resume"; A.class_ "font-medium hover:text-neutral-50 cursor-pointer" ] [ "Resume" ]
          ]
        ]
      ] *)
      H.main [ A.class_ "max-w-4xl mx-auto mx-auto px-4 sm:px-6 md:px-8 min-h-screen"] [
        H.div [ A.class_ "pt-36" ] [
          H.h1 [ A.class_ "font-swear text-center italic font-medium text-6xl" ] [
            post.data.title ^ "."
          ]
          ; H.p [ A.class_ "text-neutral-500 font-medium text-center mt-4"] [ caption ]
          ; H.article [ A.class_ "mx-auto my-20 prose prose-neutral text-neutral-800 prose-p:tracking-tighter" ] [ post.content ]
        ]
      ]
    ; footer
    (* ; Footer.elem ~source: {j|https://github.com/fahmiirsyadk/site/tree/master/src/posts/$url|j} ~fixed: false *)
    ]
  ]