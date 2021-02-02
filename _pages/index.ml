module H = Mana.HTML
module P = Mana.Property

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

let body posts =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text "Artikel");
    H.ol [] (listPost posts);
    H.footer [] [
      (H.a [
          (P.href "https://github.com/fahmiirsyadk/site")
        ][
          (H.img [
              (P.src "https://upload.wikimedia.org/wikipedia/commons/9/91/Octicons-mark-github.svg");
              (P.alt "Github icon");
              (P.style "height: 1em;")
            ] []);
          (H.span [] (H.text "View source on Github"))
        ]);
      (H.div [] []);
      (H.p [P.style "font-weight: bold;"] (H.text {js|made with 💕 from banyuwangi|js}))
    ]
  ]

let html (posts: Parser.metadata array) =
  [Partial_head.head ~title:"blog"; body posts;] |> H.html []
