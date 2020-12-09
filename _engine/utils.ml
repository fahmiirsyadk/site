type error
type remark
type colorsUnit

external colors : colorsUnit = "kleur" [@@bs.module]
external bold : 'a -> colorsUnit = "bold" [@@bs.send.pipe: colorsUnit]
external red : 'a -> colorsUnit = "red" [@@bs.send.pipe: colorsUnit]
external green : 'a -> colorsUnit = "green" [@@bs.send.pipe: colorsUnit]
external yellow : 'a -> colorsUnit = "yellow" [@@bs.send.pipe: colorsUnit]
external underline : 'a -> colorsUnit = "underline" [@@bs.send.pipe: colorsUnit]

module Console = Js.Console

external glob : string -> string array = "sync" [@@bs.module "fast-glob"]
external remark: unit -> remark = "remark" [@@bs.module]
external remarkHtml: remark = "remark-html" [@@bs.module]
external remarkFootnotes: remark = "remark-footnotes" [@@bs.module]
external remarkImages: remark = "remark-images" [@@bs.module]
external remarkToc: remark = "remark-toc" [@@bs.module]
external use: remark -> remark = "use" [@@bs.send.pipe: remark]
external processSync: 'a -> string = "processSync" [@@bs.send.pipe: remark]

(* binding NodeJS *)
module NodeJS = struct
  module Path = struct
    external join : string array -> string = "join" [@@bs.module "path"] [@@bs.splice]
    external join2 : string -> string -> string = "join" [@@bs.module "path"]
    external normalize: string -> string = "normalize" [@@bs.module "path"]
    external basename: string -> string = "basename" [@@bs.module "path"]
    external basenameNoExt: string -> string -> string = "basename" [@@bs.module "path"]
  end
  module Process = struct
    type t
    external process : t = "process"[@@bs.module ]
    external cwd : t -> string = "cwd"[@@bs.send ]
  end
end
(* end of binding *)

module Fs_Extra = struct
  external removeSync : string -> unit = "removeSync" [@@bs.module "fs-extra"]
  external readFileSync : string -> string -> string = "readFileSync" [@@bs.module "fs-extra"]
  external copy : string -> string -> unit Js.Promise.t = "copy" [@@bs.module "fs-extra"]
  external outputFileSync : string -> string -> unit = "outputFileSync" [@@bs.module "fs-extra"]
end

let logMeasure (result : float) =
  ( let str = (result |> int_of_float |> string_of_int) ^ " mseconds" in
    Console.log3
      (colors |> bold () |> green ">>>>")
      (colors |> bold "finish building")
      (colors |> bold () |> green () |> underline str)
    : unit )

let warnBanner banner err =
  Console.log2
    ( colors |> bold ()
      |> yellow (">>> " ^ banner ^ " with message: \n") )
    err;
  Console.log (colors |> bold () |> yellow ">>> End line of warn message \n")

let errorBanner banner err =
  Console.log2
    ( colors |> bold ()
      |> red (">>>" ^ {j| 😱 |j} ^ banner ^ " with message: \n") )
    err;
  Console.log (colors |> bold () |> red ">>> End line of error message \n")
