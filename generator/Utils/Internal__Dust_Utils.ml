type writeFileOptions

type recursiveReaddirOptions = {
  overwrite: bool;
  dot: bool;
  results: bool;
}

external writeFileOptions: ?mode: int -> ?flag: string -> ?encoding: string -> unit -> writeFileOptions = "" [@@bs.obj]
external outputFile: string -> string -> ?options: writeFileOptions -> unit -> unit Promise.t = "outputFile" [@@bs.module "fs-extra"]
external copy: string -> string -> unit Promise.t = "copy" [@@bs.module "fs-extra"]
external ensureDir: string -> unit Promise.t = "ensureDir" [@@bs.module "fs-extra"]
external readFile: string -> string -> string Js.Promise.t = "readFile" [@@bs.module "fs"] [@@bs.scope "promises"]
external emptyDirSync: string -> unit = "emptyDirSync" [@@bs.module "fs-extra"]
external emptyDir: string -> unit Promise.t = "emptyDir" [@@bs.module "fs-extra"]
external remove: string -> unit Promise.t = "remove" [@@bs.module "fs-extra"]
external recCopy: string -> string -> recursiveReaddirOptions -> unit Promise.t = "recursive-copy" [@@bs.module]

let flatten (arr: 'a array array) = arr |> Array.to_list |> Array.concat

module Klaw = struct
  type t
  external klaw: 'a -> t = "default" [@@bs.module "klaw"]
  external on: t -> string -> ('a -> 'b) -> t = "on" [@@bs.send]
end

module Kleur = struct
  type t
  external kleur: t = "kleur" [@@bs.module]
  external bold: t -> 'a -> t = "bold" [@@bs.send]
  external red: t -> 'a -> t = "red" [@@bs.send]
  external green: t -> 'a -> t = "green" [@@bs.send]
  external yellow: t -> 'a -> t = "yellow" [@@bs.send]
  external blue: t -> 'a -> t = "blue" [@@bs.send]
end

module ErrorMessage = struct
  open Kleur
  type t = 
  | Errors of string
  | Warnings of string
  | Info of string

  let logMessage msg = 
    (
      match msg with
      | Errors msg -> kleur |. bold () |. red {j|--- Oh no, we found error ---\n $msg \n-----------------------------\n|j}
      | Warnings msg -> kleur |. bold () |. red {j|--- Just in case, warning ---\n $msg \n-----------------------------\n|j}
      | Info msg -> kleur |. bold () |. red {j|--- Information for you ---\n $msg \n-----------------------------\n|j}
    ) |> Js.log
end

module Chokidar = struct
  type t

  type awaitWriteFinishOptions = {
    stabilityThreshold: int;
    pollInterval: int;
  }

  type watchConfig = {
    ignored: string array;
    ignoreInitial: bool;
    awaitWriteFinish: awaitWriteFinishOptions;
    depth: int;
  }

  external watcher: t = "chokidar" [@@bs.module]
  external watch: t -> string -> watchConfig -> t = "watch" [@@bs.send]
  external on: t -> string -> ('a -> unit) -> t = "on" [@@bs.send]
end

module LiveServer = struct
  type t
  
  type serverConfig = {
    root: string;
    logLevel: int;
    opens: bool [@bs.as "open"]; 
  }

  external server: t = "live-server" [@@bs.module]
  external start: t -> serverConfig -> unit = "start" [@@bs.send]
  (* @module external server: t = "live-server" *)
  (* @send external start: (t, serverConfig) => unit = "start" *)
end

let readImportML =
  [%raw
    {|
  function (meta, filepath, output) {
    const decache = require('decache')
    let res = require(`${filepath}`)
    decache(`${filepath}`)
    res = require(`${filepath}`)

    const status = res.main ? true : false
      
    if(status) {
      return { status, path: output, content: res.main(meta) }
      } else {
        return { status, path: output, content: `` }
      }
    }
|}]

let deleteAllCache =
  [%raw {|
  function() {
    Object.keys(require.cache).forEach(function(key) {
      delete require.cache[key]
    })
  }
  |}]
