module H = Mana.HTML
module P = Mana.Property
module L = Layout_post

let body (post: Parser.metadata) =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text post.matter.title);
    H.span [] (H.text ("tanggal rilis: " ^ post.matter.date));
    H.div [] (H.text post.content);
  ]

let html (post: Parser.metadata) =
  L.template (body post) post
