module H = Mana.HTML
module P = Mana.Property

module App = Layout_app

let listPost posts =
  Belt.List.map (Array.to_list posts)
    (fun (post: Parser.metadata) ->
       H.a [
         (P.href post.url);
         (P.style "color: #444;")
       ] [
         (H.li [] (H.text post.matter.title));
       ]
    )

let themeJS = Mana.Extra.inject("assets/js/theme.js")

let body posts =
  H.body [] [
   H.button [
    (P.id "theme-toggle");
    (P.type_ "button");
   ] [
    (H.span [] (H.text "moon"));
    (H.span [] (H.text "shine"));
   ];
    H.h1 [] (H.text "Artikel");
    H.ol [] (listPost posts);
  ]

let html (posts: Parser.metadata array) =
  App.layout (Partial_head.head ~title: "blog") (body posts)
