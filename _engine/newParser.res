module Path = Node.Path
module Extra = Utils.Fs_Extra
module Process = Utils.NodeJS.Process

// Binding
type unified
type propertiesAst = {
  title: string,
  date: string,
  template: string,
}

type orgAst = {
  properties: propertiesAst
}

type metadata = {
  filename: string,
  url: string,
  content: string,
  matter: propertiesAst,
}

@module external unified: unit => unified = "unified"
@module external reorgParse: unified = "reorg-parse"
@module external reorgMutate: unified = "reorg-rehype"
@module external html: unified = "remark-html"
@module external rehypeStringify: unified = "rehype-stringify"
@module external remarkStringify: unified = "remark-stringify"
@module external remarkParse: unified = "remark-parse"
@module external tomdast: 'a => unified = "hast-util-to-mdast"  
@module external remarkFrontmatter: string => unified = "remark-frontmatter"
@module external parseYaml: unified = "remark-parse-yaml"
@module external rehypeRemark: unified = "rehype-remark"
@module("orga") external parseOrga: string => orgAst = "parse"  
@send external use: (unified, unified) => unified = "use"
@send external parse: (unified, 'a) => string = "parse"  
@send external processSync: (unified, 'a) => string = "processSync"

let normalizePath = (path: string) => path
  -> Path.join2(Process.process->Process.cwd)
  -> Path.normalize

let outputDir = (dir: string) => dir -> normalizePath
let cleanDir = (path: string) => path 
  -> normalizePath
  -> Extra.removeSync

let globPath = (path: array<string>) => path
  -> Path.join
  -> Path.normalize
  -> Utils.glob

let getPages: array<string> = [Process.cwd(Process.process), "_pages", "**", "*.ml"]-> globPath
let getPosts: array<string> = [Process.cwd(Process.process), "_posts", "**", "*.org"]-> globPath
  
let orgToHtml = (path: string) => unified()
  -> use(reorgParse)
  -> use(reorgMutate)
  -> use(rehypeStringify)
  -> parse(path)

let getMetadata = (path: string ) => parseOrga(path);

let importManaFile = %raw(`
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
`)

// LOOPING ALL FILES AND PROCESS THEM
let processOrg: array<string> = Js.Array2.map(getPosts, path => Node.Fs.readFileAsUtf8Sync(path) -> orgToHtml)
let processMatter: array<propertiesAst> = Js.Array2.map(getPosts, path => Node.Fs.readFileAsUtf8Sync(path) -> getMetadata) -> Js.Array2.map(orgAst => orgAst.properties)

/*
let sortMatterByDate =
  processMatter->Js.Array2.sortInPlaceWith((a, b) =>
    a.matter.data.date < b.matter.data.date ? 1 : -1
)

 */
                                                       
let metadataPost = (content, matter, path) => {
  let pathNoExt = path -> Path.basename_ext(".org");
  { filename: pathNoExt,
    url: "blog/" ++ pathNoExt,
    content: content,
    matter: matter,
  }
}
