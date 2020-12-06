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

type typeMatterData = {
  title: string;
  date: string;
}

type typeMatter = {
  data: typeMatterData;
  isEmpty: bool;
  excerpt: string;
}

type metadata = {
  filename: string;
  path: string;
  content: string;
  matter: typeMatter;
}

module Extra = Utils.Fs_Extra
module Path = Utils.NodeJS.Path
module Process = Utils.NodeJS.Process
external matter: string -> 'a = "gray-matter" [@@bs.module]

let cleanDir (path: string) = path |> Path.join2 (Process.cwd Process.process)
                              |> Path.normalize
                              |> Extra.removeSync

let getGlob (path: string array) = path
                                   |> Path.join
                                   |> Path.normalize
                                   |> Utils.glob

let getPages = [| Process.cwd Process.process; "pages"; "**"; "*.ml"; |] |> getGlob
let getPosts = [| Process.cwd Process.process; "posts"; "**"; "*.md"; |] |> getGlob

(* markdown *)
let processMd: string array = Belt.Array.map getPosts (fun x -> (Extra.readFileSync x "utf8"))

let postMd = (Belt.Array.map processMd (fun x -> matter x))
             |. Belt.Array.map (fun x -> x.data)
             |> Js.Array.sortInPlaceWith (fun a b ->
                 match (a.date < b.date) with
                 | true -> 1
                 | false -> -1
               )

let generatePage (outputPath: string) (filename: string) (manafile: string) =
  Node.Fs.writeFileSync (outputPath ^ filename ^ ".html") manafile `utf8

let run = (fun _ -> cleanDir "dist"; ())
