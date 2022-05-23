module H = Dust.Html.Elements
module A = Dust.Html.Attributes

type matter = { title : string }

type blog =
  { name : string
  ; layout : string
  ; source : string
  ; data : matter
  ; excerpt : string
  ; url : string
  ; content : string
  }

type posts = { blog : blog array }

let listPost blog =
  blog |. Belt.List.map (fun post ->
    H.article [] [
      H.a [ A.href post.url ] [
        H.h1 [ A.class_ "text-2xl text-neutral-200 font-semibold underline underline-offset-2 hover:underline-offset-4" ] (H.text post.data.title)
      ]
    ]
  )

let main posts =
  let blog = posts.blog |> Array.to_list in
  H.html [] [
    Seo.head ~children:"" ()
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
          H.h1 [ A.class_ "text-neutral-100 font-swear text-center italic font-medium text-6xl" ] [ "Blog" ]
          ; H.article [ A.class_ "mx-auto text-center mt-20" ] (listPost blog)
        ]
      ]
    ]
  ]