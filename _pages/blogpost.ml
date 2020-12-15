module H = Mana.HTML
module P = Mana.Property

let body (post: Parser.metadata) =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text post.matter.title);
    H.div [] (H.text post.content);
  ]

let html (post: Parser.metadata) =
  [Partial_head.head ~title:"blog"; body post;] |> H.html []
