open Utils.Org
module Path = Node.Path
module Extra = Utils.Fs_Extra
module Process = Utils.NodeJS.Process

@module external unixify: string => string = "unixify"

type metadata = {
  filename: string,
  url: string,
  content: string,
  matter: Utils.propertiesAst,
}

let rootPath = Process.process->Process.cwd

let normalizePath = (path: string) => path->Path.join2(rootPath)->Path.normalize

let outputDir = (dir: string) => dir->normalizePath
let cleanDir = (path: string) => path->Extra.emptyDirSync

let globPath = (path: array<string>) => {
  Js.log(path->Path.join)
  path->Path.join->unixify->Utils.glob
}

let getPages: array<string> = [rootPath, "_pages", "**", "*.ml"]->globPath
let getPosts: array<string> = [rootPath, "_posts", "**", "*.org"]->globPath

let orgToHtml = (path: string): Utils.vfile =>
  unified()->use(reorgParse)->use(reorgMutate)->use(rehypeStringify)->processSync(path)

let getMatterData = (path: string) => parseOrga(path)

let importManaFile = %raw(`
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
`)

let metadataPost = (content, matter, path) => {
  let pathNoExt = path->Path.basename_ext(".org")
  {
    filename: pathNoExt,
    url: Path.join(["blog", pathNoExt]),
    content: content,
    matter: matter,
  }
}

let sortMatterByDate = (listmeta: array<metadata>) =>
  listmeta->Js.Array2.sortInPlaceWith((a, b) => a.matter.date < b.matter.date ? 1 : -1)

let processMetadata: array<metadata> = Js.Array2.map(getPosts, path => {
  let processMatter = path->Node.Fs.readFileAsUtf8Sync->getMatterData
  let processContent = path->Node.Fs.readFileAsUtf8Sync->orgToHtml
  metadataPost(processContent.contents, processMatter.properties, path)
})->sortMatterByDate

let generatePosts = () => {
  Js.Array2.forEach(processMetadata, meta => {
    let post = Path.join([rootPath, "_pages", "blogpost" ++ ".bs.js"])->importManaFile(meta)
    Path.join([rootPath, "dist", meta.url, "index.html"])->Extra.outputFileSync(post)
  })
}

let generatePage = (meta, path, basename) => {
  Path.join([rootPath, "_pages", basename ++ ".bs.js"])
  ->Path.normalize
  ->importManaFile(meta)
  ->Extra.outputFileSync(Path.join([rootPath, "dist", path]), _)
}

let generateHtml = () => {
  getPages->Js.Array2.forEach(pages => {
    let basename = pages->Path.basename_ext(".ml")
    switch basename {
    | "blogpost" => generatePosts()
    | "404" | "index" => generatePage(processMetadata, j`$basename.html`, basename)
    | _ => generatePage(processMetadata, Path.join([basename, "index.html"]), basename)
    }
  })
}

let run = () => {
  cleanDir("dist")
  generateHtml()
}
