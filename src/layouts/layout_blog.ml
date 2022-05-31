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
  |}
]

let main post =
  let caption = 
    match post.data.caption with
    | Some(data) -> data
    | None -> ""
in
  let filterUrl = if post.name == "blog" then "articles" else post.name 
in
  let url = (Node.Path.join2 filterUrl (post.page |> Node.Path.basename))
  |> Node.Path.normalize 
in
  H.html [ A.lang "en" ] [
    Seo.head ~children: markdownStyle ()
  ; H.body [ A.class_ "bg-neutral-900" ] [
      H.header [ A.class_ "w-full select-none h-20 fixed top-0 text-neutral-400 flex items-center justify-center"; A.style "background: linear-gradient(0deg, rgba(0,0,0,0) 0%, rgba(23,23,23,0.8) 82%, rgba(23,23,23,1) 100%);" ] [
        H.nav [ A.class_ "flex items-center content-center"; ] [
          H.div [ A.class_ "space-x-6" ] [
            H.a [ A.href "/blog"; A.class_ "font-medium text-neutral-50 cursor-pointer" ] [ "Blog" ]
          ; H.a [ A.href "/projects"; A.class_ "font-medium hover:text-neutral-50 cursor-pointer" ] [ "Projects" ]
          ]
        ; H.div [ A.class_ "mx-6 cursor-pointer" ] [
            H.a [ A.href "/" ] [
              Logo.logoRatio 30 "#f5f5f5"
            ]
          ]
        ; H.div [ A.class_ "space-x-6" ] [
            H.a [ A.href "/about"; A.class_ "font-medium hover:text-neutral-50 cursor-pointer" ] [ "About" ]
          ; H.a [ A.href "/resume"; A.class_ "font-medium hover:text-neutral-50 cursor-pointer" ] [ "Resume" ]
          ]
        ]
      ]
    ; H.main [ A.class_ "max-w-4xl mx-auto min-h-screen"] [
        H.div [ A.class_ "pt-36" ] [
          H.h1 [ A.class_ "text-neutral-100 font-swear text-center italic font-medium text-6xl" ] [
            post.data.title ^ "."
          ]
          ; H.p [ A.class_ "text-neutral-500 font-medium text-center mt-4"] [ caption ]
          ; H.article [ A.class_ "mx-auto my-20 prose dark:prose-invert selection:bg-purple-300 selection:text-black selection:font-semibold" ] [ post.content ]
        ]
      ]
    ; Footer.elem ~source: {j|https://github.com/fahmiirsyadk/site/tree/master/src/posts/$url|j} ~fixed: false
    ]
  ]