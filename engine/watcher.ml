type chokidar


type watchConfig = {
  ignored: string;
  persistent: bool;
}

external watcher: chokidar = "chokidar" [@@bs.module]
external watch: string array -> watchConfig -> chokidar = "watch" [@@bs.send.pipe: chokidar]
external on: string -> ('a -> unit) -> chokidar = "on" [@@bs.send.pipe: chokidar]

let run () =
  let target = [| "layouts";"pages";"posts"; |] in
  let config = { ignored="*.bs.js"; persistent=true; } in

  (watcher |> watch target config)
  |> on "add" (fun path -> Parser.run(); Js.log {j|$path ditambahkan|j})
  |> on "change" (fun path -> Parser.run(); Js.log {j|$path diubah|j})
  |> on "unlink" (fun path -> Parser.run(); Js.log {j|$path dihapus|j})
