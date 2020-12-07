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

type typeMatter = {
  title: string;
  date: string;
}

type metadata = {
  filename: string;
  url: string;
  content: string;
  matter: typeMatter;
  excerpt: string;
}

type graymatter = {
  content: string;
  data: typeMatter;
  isEmpty: bool;
  excerpt: string;
}

module Extra = Utils.Fs_Extra
module Path = Utils.NodeJS.Path
module Process = Utils.NodeJS.Process
external matter: string -> 'a = "gray-matter" [@@bs.module]


let outDir = "dist"
             |> Path.join2 (Process.cwd Process.process)
             |> Path.normalize

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

let processMatter: graymatter array = (Belt.Array.map processMd (fun x -> matter x))

let sortMatterByDate: graymatter array = processMatter
                                         |> Js.Array.sortInPlaceWith (fun a b ->
                                             match (a.data.date < b.data.date) with
                                             | true -> 1
                                             | false -> -1
                                           )


let generatePage (outputPath: string) (filename: string) (manafile: string) =
  Extra.readFileSync (outputPath ^ filename ^ ".html") manafile

let importManaFile = [%raw {|
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
|}]

let readMarkdown = [%raw {|
  function(content) {
     const remark = require('remark')
     const html = require('remark-html')
     const data = remark()
        .use(html)
        .processSync(content)
     return data.toString()
    }
|}]

let metadataPost path (matter: graymatter) = {
  filename = "name";
  url = path;
  content =  matter.content |> readMarkdown;
  excerpt = matter.excerpt;
  matter = matter.data;
}


let createMetaData = sortMatterByDate
                     |> Array.map (fun (post: graymatter) -> (post |> metadataPost "/blog/test"))

let _ = Js.log createMetaData
 (*
 *
let executeMana (path: string) =
  importManaFile (
    (Path.join [|(Process.cwd Process.process); "pages"; path ^ ".bs.js";|]
     |> Path.normalize)) sortMatterByDate

 * *)

(*
let _ = sortMatterByDate |> Array.map (fun (post: typeMatterData) -> Js.log (post |> metadataPost "/blog/test"))
*)

 (*
let _ = executeMana "blog" |> generatePage "" "jajal"
*)

let run = (fun _ -> cleanDir "dist"; ())
