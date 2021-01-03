type error
type remark

module Console = Js.Console

@module("fast-glob") external glob: string => array<string> = "sync"
@module external remark: unit => remark = "remark"
@module external remarkHtml: remark = "remark-html"
@module external remarkFootnotes: remark = "remark-footnotes"
@module external remarkImages: remark = "remark-images"
@module external remarkToc: remark = "remark-toc"
@bs.send.pipe(: remark) external use: remark => remark = "use"
@bs.send.pipe(: remark) external processSync: 'a => string = "processSync"

/* binding NodeJS */
module NodeJS = {
  module Path = {
    @module("path") @splice external join: array<string> => string = "join"
    @module("path") external join2: (string, string) => string = "join"
    @module("path") external normalize: string => string = "normalize"
    @module("path") external basename: string => string = "basename"
    @module("path") external basenameNoExt: (string, string) => string = "basename"
  }
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
}
