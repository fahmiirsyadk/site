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
    H.div [] [
      H.a [] [ A.href post.url ]
      ; H.h1 [] (H.text post.data.title)
    ]
  )

let main posts =
  let blog = posts.blog |> Array.to_list in
  H.html [] [
    Seo.head ~children: "" ()
    ; H.body [] [
        H.p [] (H.text "Blog posts")
        ; H.div [] (listPost blog)
    ]
  ]