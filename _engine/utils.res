type error
type unified

type propertiesAst = {
  title: string,
  date: string,
  template: string,
}

type orgAst = {
  properties: propertiesAst
}

type vfile = {
  contents: string
}

@module("fast-glob") external glob: string => array<string> = "sync"

/* binding NodeJS */
module NodeJS = {
  module Process = {
    type t
    @module external process: t = "process"
    @send external cwd: t => string = "cwd"
  }
}
/* end of binding */

module Fs_Extra = {
  @module("fs-extra") external removeSync: string => unit = "removeSync"
  @module("fs-extra") external readFileSync: (string, string) => string = "readFileSync"
  @module("fs-extra") external copy: (string, string) => Js.Promise.t<unit> = "copy"
  @module("fs-extra") external outputFileSync: (string, string) => unit = "outputFileSync"
  @module("fs-extra") external emptyDirSync: string => unit = "emptyDirSync"
}

@module external unified: unit => unified = "unified"
@module external reorgParse: unified = "reorg-parse"
@module external reorgMutate: unified = "reorg-rehype"
@module external rehypeStringify: unified = "rehype-stringify"
@module("orga") external parseOrga: string => orgAst = "parse"  
@send external use: (unified, unified) => unified = "use"
@send external parse: (unified, 'a) => string = "parse"  
@send external processSync: (unified, 'a) => vfile = "processSync"
