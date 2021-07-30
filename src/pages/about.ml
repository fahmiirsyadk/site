module H = Mana.HTML
module P = Mana.Property

module App = Layout_app

let body =
  H.body [P.class_ "theme"] [
    H.h1 [] (H.text "About me");
    H.p [] (H.text "Soon");
    H.img [
      (P.alt "makima doing cursed stuff");
      (P.src "https://i.ytimg.com/vi/usr7UZthAos/hqdefault.jpg")
    ] []
  ]

let main () =
  App.layout (Partial_head.head ~title: "about") (body)
