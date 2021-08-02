type error
type unified
type colors

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

module Fs_Extra = {
  @module("fs-extra") external removeSync: string => unit = "removeSync"
  @module("fs-extra") external readFileSync: (string, string) => string = "readFileSync"
  @module("fs-extra") external copy: (string, string) => Js.Promise.t<unit> = "copy"
  @module("fs-extra") external outputFileSync: (string, string) => unit = "outputFileSync"
  @module("fs-extra") external emptyDirSync: string => unit = "emptyDirSync"
}

module Org = {    
  @module external unified: unit => unified = "unified"
  @module external reorgParse: unified = "reorg-parse"
  @module external reorgMutate: unified = "reorg-rehype"
  @module external rehypeStringify: unified = "rehype-stringify"
  @module("orga") external parseOrga: string => orgAst = "parse"
  @send external use: (unified, unified) => unified = "use"
  @send external parse: (unified, 'a) => string = "parse"
  @send external processSync: (unified, 'a) => vfile = "processSync"
}

module Kleur = {
  @module external kleur: colors = "kleur"
  @send external bold: (colors, 'a) => colors = "bold"
  @send external green: (colors, 'a) => colors = "green"
  @send external yellow: (colors, 'a) => colors = "yellow"
  @send external blue: (colors, 'a) => colors = "blue"
  @send external underline: (colors, 'a) => colors = "underline"
  @send external red: (colors, 'a) => colors = "red"
}