module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra
module Path = Utils.NodeJS.Path
module Process = Utils.NodeJS.Process

let head ~title:(title: string) =
  H.head [] [
    H.title [] (H.text title);
    H.style [] (H.text (E.inject "partials/main.css"));
  ]
