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

type matterAndPath = {
  matter: graymatter;
  path: string;
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

let getPages: string array = [| Process.cwd Process.process; "_pages"; "**"; "*.ml"; |] |> getGlob
let getPosts: string array = [| Process.cwd Process.process; "_posts"; "**"; "*.md"; |] |> getGlob

(* markdown *)
let processMd: (string * string) array = Belt.Array.map getPosts (fun x -> (Extra.readFileSync x "utf8", x))

let processMatter: matterAndPath array = (Belt.Array.map processMd (fun (x,y) -> { matter=(matter x); path=y; }))

let sortMatterByDate = processMatter
                       |> Js.Array.sortInPlaceWith (fun a b ->
                           match (a.matter.data.date < b.matter.data.date) with
                           | true -> 1
                           | false -> -1
                         )

let parseMarkdown content =
  Utils.remark()
  |> Utils.use Utils.remarkFootnotes
  |> Utils.use Utils.remarkImages
  |> Utils.use Utils.remarkToc
  |> Utils.use Utils.remarkHtml
  |> Utils.processSync content

let metadataPost path (matter: graymatter) = {
  filename = "name";
  url = "blog/" ^ (path |. Path.basenameNoExt ".md");
  content =  matter.content |> parseMarkdown;
  excerpt = matter.excerpt;
  matter = matter.data;
}

let createMetaData: metadata array = sortMatterByDate
                                     |> Array.map (fun (post: matterAndPath) -> (post.matter |> metadataPost post.path))

let importManaFile = [%raw {|
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
|}]

(* blogpost *)
let generatePosts () = Belt.Array.forEach createMetaData
    (fun (meta: metadata) ->
       let basename = (Path.basenameNoExt meta.url ".md") in
       let blogpostPath = ((Path.join [|(Process.cwd Process.process); "_pages"; "blogpost" ^ ".bs.js";|])) in
       importManaFile blogpostPath meta |> Extra.outputFileSync ({j|dist/blog/$basename/index|j} ^ ".html")
    )

let generatePages () = Belt.Array.forEach getPages
    (fun path ->
       let basename = (Path.basenameNoExt path ".ml") in
       match basename with
       | "blogpost" -> generatePosts()
       | _ -> (
           ((Path.join [|(Process.cwd Process.process); "_pages"; basename ^ ".bs.js";|])
            |> Path.normalize)
           |. importManaFile createMetaData
           |> Extra.outputFileSync ({j|dist/$basename|j} ^ ".html")
         )
    )

let run = (fun _ -> cleanDir "dist"; generatePages())
