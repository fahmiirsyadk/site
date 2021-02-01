module H = Mana.HTML
module P = Mana.Property

let listPost posts =
  Belt.List.map (Array.to_list posts)
    (fun (post: Parser.metadata) ->
       H.a [ P.href post.url] [
         (H.li [] (H.text post.matter.title));
       ]
    )

let body posts =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text "Artikel saat ini");
    H.ol [] (listPost posts);
    H.footer [] [
      H.b [] (H.text "made with <3 from banyuwangi")
    ]
  ]

let html (posts: Parser.metadata array) =
  [Partial_head.head ~title:"blog"; body posts;] |> H.html []
