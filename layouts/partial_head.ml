module H = Mana.HTML
module P = Mana.Property

let head ~title:(title: string) =
  H.head [] [
    H.title [] (H.text title);
    H.style [] (H.text {j|
       .theme {
            background: black;
            color: white;
        }
    |j});
  ]
