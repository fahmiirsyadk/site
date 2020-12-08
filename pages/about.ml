module H = Mana.HTML
module P = Mana.Property

let body =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text "ini judul");
    H.p [] (H.text "ini deskripsi");
    H.img [
      (P.alt "makima doing cursed stuff");
      (P.src "https://i.ytimg.com/vi/usr7UZthAos/hqdefault.jpg")
    ] []
  ]

let html () =
  [Partial_head.head ~title:"blog"; body;] |> H.html []
