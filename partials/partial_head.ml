module H = Mana.HTML
module P = Mana.Property
module Path = Utils.NodeJS.Path
module Process = Utils.NodeJS.Process

let importCss: string =
  Utils.Fs_Extra.readFileSync
    (Path.join [|(Process.cwd Process.process); "partials"; "main.css";|]
     |> Path.normalize) "utf-8"

let head ~title:(title: string) =
  H.head [] [
    H.title [] (H.text title);
    H.style [] (H.text importCss);
  ]
