module H = Dust.Html.Elements
module A = Dust.Html.Attributes

type dataPost = { title : string }

type post =
  { content : string
  ; data : dataPost
  }

let main (post : post) =
  H.html [] [
    Seo.head ~children:"" ()
  ; H.body [] [
      H.main [ A.class_ "max-w-5xl mx-auto min-h-screen"] [
        H.h1 [] (H.text post.data.title)
      ; H.div [] [ post.content ]
      ]
    ]
  ]