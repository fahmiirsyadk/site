module H = Mana.HTML
module P = Mana.Property

let head =
  H.head [] [
    H.title [] (H.text "ini demo");
    H.style [] (H.text {j|
       .theme {
            background: black;
            color: white;
        }
    |j});
  ]

let listPost posts =
  Belt.List.map (Array.to_list posts)
    (fun (post: Parser.typeMatterData) -> H.li [] (H.text post.title))

let body posts =
  H.body [P.class_ "theme"] [
    H.ol [] (listPost posts);
    H.h1 [] (H.text "ini judul");
    H.p [] (H.text "ini deskripsi");
    H.img [
      (P.alt "makima doing cursed stuff");
      (P.src "https://i.ytimg.com/vi/usr7UZthAos/hqdefault.jpg")
    ] []
  ]

let html (posts: Parser.typeMatterData array) =
  [head; body posts;] |> H.html []
