(* start logging time *)
(* delete previous build folder *)
(* create blog folder *)
(* get all pages & posts data *)
(* get page filename ( used for invidual html page ) *)
(* get graymatter data *)
(* passing gray matter to pages files *)
(* parse markdown to html *)
(* passing data markdown (html) to blogpost file *)
(* parse data pages (.ml) to html *)
(* send to the output dir *)
(* parse individual blog post file & send them to the output blog dir *)
(* end logging time *)

module Extra = Utils.Fs_Extra
module Path = Utils.NodeJS.Path
module Process = Utils.NodeJS.Process

let cleanDir (path: string) = path |> Path.join2 (Process.cwd Process.process)
                              |> Path.normalize
                              |> Extra.removeSync

let generatePage (manafile: string) (outputPath: string) (filename: string) =
  Node.Fs.writeFileSync (outputPath ^ filename ^ ".html") manafile `utf8



let run = (fun _ -> cleanDir "dist"; ())
