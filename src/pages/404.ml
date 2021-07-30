module H = Mana.HTML
module P = Mana.Property

module App = Layout_app

let body =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text "Uh oh... halaman tidak ditemukan");
  ]

let main () =
  App.layout (Partial_head.head ~title:"404") body
