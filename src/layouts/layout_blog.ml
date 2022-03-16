module H = Dust.Html.Elements
module A = Dust.Html.Attributes

type dataPost = { title : string }

type post =
  { content : string
  ; data : dataPost
  ; name : string
  ; layout : string
  ; source : string
  ; excerpt : string
  ; url : string
  }

let markdownStyle = "p { margin-bottom: 16px }"

let main post =
  H.html [] [
    Seo.head ~children:"" ()
  ; H.body [ A.class_ "bg-black" ] [
      H.header [ A.class_ "w-full select-none h-20 fixed top-0 text-neutral-400 flex items-center justify-center"; A.style "background: linear-gradient(0deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.8) 72%, rgba(0,0,0,1) 100%);" ] [
        H.nav [ A.class_ "flex items-center content-center"; ] [
          H.div [ A.class_ "space-x-6" ] [
            H.a [ A.href "/blog"; A.class_ "font-medium text-neutral-50 cursor-pointer" ] [ "Blog" ]
          ; H.a [ A.href "/projects"; A.class_ "font-medium hover:text-neutral-50 cursor-pointer" ] [ "Project" ]
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
          ; H.p [ A.class_ "text-neutral-500 font-medium text-center mt-4"] [ post.excerpt ]
          ; H.article [ A.class_ "mx-auto mt-20 prose dark:prose-invert selection:bg-purple-300 selection:text-black selection:font-semibold" ] [ post.content ]
        ]
      ]
    ]
  ]