module H = Mana.HTML
module P = Mana.Property

let body =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text "Uh oh... halaman tidak ditemukan");
  ]

let html () =
  [Partial_head.head ~title:"404"; body;] |> H.html []
