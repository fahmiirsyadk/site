open Utils;
module Path = Node.Path
module Extra = Fs_Extra
module Process = NodeJS.Process

type metadata = {
  filename: string,
  url: string,
  content: string,
  matter: propertiesAst,
}
  
let normalizePath = (path: string) => path
  -> Path.join2(Process.process->Process.cwd)
  -> Path.normalize

let outputDir = (dir: string) => dir -> normalizePath
let cleanDir = (path: string) => path -> Extra.emptyDirSync

let globPath = (path: array<string>) => path
  -> Path.join
  -> Path.normalize
  -> Utils.glob

let getPages: array<string> = [Process.cwd(Process.process), "_pages", "**", "*.ml"]-> globPath
let getPosts: array<string> = [Process.cwd(Process.process), "_posts", "**", "*.org"]-> globPath
  
let orgToHtml = (path: string): vfile => unified()
  -> use(reorgParse)
  -> use(reorgMutate)
  -> use(rehypeStringify)
  -> processSync(path)

let getMatterData = (path: string ) => parseOrga(path);

let importManaFile = %raw(`
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
`)

let metadataPost = (content, matter, path) => {
  let pathNoExt = path -> Path.basename_ext(".org");
  { filename: pathNoExt,
    url: "blog/" ++ pathNoExt,
    content: content,
    matter: matter,
  }
}
  
let sortMatterByDate = (listmeta: array<metadata>) =>
  listmeta -> Js.Array2.sortInPlaceWith((a, b) =>
    a.matter.date < b.matter.date ? 1 : -1
)

let processMetadata: array<metadata> =
  Js.Array2.map(getPosts, path => { 
    let processMatter = path -> Node.Fs.readFileAsUtf8Sync -> getMatterData
    let processContent = path -> Node.Fs.readFileAsUtf8Sync -> orgToHtml
    metadataPost(processContent.contents, processMatter.properties, path);
})->sortMatterByDate

let generatePosts = () => {
  Js.Array2.forEach(processMetadata, meta => {
    let blogpostPath = Path.join([Process.cwd(Process.process), "_pages", "blogpost" ++ ".bs.js"])
    let filename = meta.filename
    j`dist/blog/$filename/index.html` -> Extra.outputFileSync(blogpostPath -> importManaFile(meta))
  })
}

let generateHtml = () => {
  getPages -> Js.Array2.forEach(pages => {
    let basename = pages -> Path.basename_ext(".ml");
    switch basename {
    | "blogpost" => generatePosts()
    | _ => Path.join([Process.process->Process.cwd, "_pages", basename ++ ".bs.js"])
      -> Path.normalize
      -> importManaFile(processMetadata)
      -> Extra.outputFileSync(j`dist/$basename` ++ ".html", _)
    }
  })
}

let run = () => {
  cleanDir("dist")
  generateHtml()
}
