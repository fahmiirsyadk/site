module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let head ~title:(title: string) =
  H.head [] [
    H.link [
      P.rel "preconnect";
      P.href "https://fonts.gstatic.com";
    ] [];
    H.link [
      P.href "https://fonts.googleapis.com/css2?family=Libre+Baskerville:ital@0;1&display=swap";
      P.rel "stylesheet";
    ] [];
    H.link [
      P.href "https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;700&display=swap";
      P.rel "stylesheet";
    ] [];
    H.title [] (H.text title);
    H.style [] (H.text (E.inject "assets/css/style.css"));
  ]
