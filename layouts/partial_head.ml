module H = Mana.HTML
module P = Mana.Property

let head ~title:(title: string) =
  H.head [] [
    H.title [] (H.text title);
    H.style [] (H.text {j|
        :root {
          --width-max: 64rem;
        }
       html {
          width: var(--width-max);
          margin: 0 auto;
        }
       .theme {
            color: #333;
        }
    |j});
  ]
