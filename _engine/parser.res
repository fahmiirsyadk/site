open Utils.Org
module Path = Node.Path
module Extra = Utils.Fs_Extra
module Process = Node.Process

type metadata = {
  filename: string,
  url: string,
  content: string,
  matter: Utils.propertiesAst,
}

let rootPath = Process.cwd()

let normalizePath = (path: string) => path->Path.join2(rootPath)->Path.normalize

let outputDir = (dir: string) => dir->normalizePath
let cleanDir = (path: string) => path->Extra.emptyDirSync

let globPath = (path: array<string>) => {
  path->Path.join->Utils.glob
}

let getPages: array<string> = [rootPath, "src", "pages", "**", "*.ml"]->globPath
let getPosts: array<string> = [rootPath, "src", "posts", "**", "*.org"]->globPath

let orgToHtml = (path: string): Utils.vfile =>
  unified()->use(reorgParse)->use(reorgMutate)->use(rehypeStringify)->processSync(path)

let getMatterData = (path: string) => parseOrga(path)

let importManaFile = %raw(`
  function(path, props) {
    let data = require(path);
    return data.main(props);
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
    let post = Path.join([rootPath, "src", "pages", "blogpost" ++ ".bs.js"])->importManaFile(meta)
    Path.join([rootPath, "dist", meta.url, "index.html"])->Extra.outputFileSync(post)
  })
}

let generatePage = (meta, path, basename) => {
  Path.join([rootPath, "src", "pages", basename ++ ".bs.js"])
  ->Path.normalize
  ->importManaFile(meta)
  ->Extra.outputFileSync(Path.join([rootPath, "dist", path]), _)
}

/* Hardcode copy assets ( fonts, images ) to dist */
let copyAssets = () => {
  let publicFolder = path => Path.join([rootPath, "src", path])
  let assetFolder = path => Path.join([rootPath, "src", "assets", path])
  let destFolder = paths => Path.join(paths |> Js.Array2.concat([rootPath, "dist"]))
  let _ = Js.Promise.all([
    Extra.copy(assetFolder("fonts"), destFolder(["assets", "fonts"])),
    Extra.copy(assetFolder("images"), destFolder(["assets", "images"])),
    Extra.copy(assetFolder("js"), destFolder(["assets", "js"])),
    Extra.copy(publicFolder("public"), destFolder([])),
  ])
}

let generateHtml = () => {
  getPages->Js.Array2.forEach(pages => {
    let basename = pages->Path.basename_ext(".ml")
    switch basename {
    | "blogpost" => generatePosts()
    | "404" | "index" | "offline" => generatePage(processMetadata, j`$basename.html`, basename)
    | _ => generatePage(processMetadata, Path.join([basename, "index.html"]), basename)
    }
  })
}

// auto compress css in folder assets css
let compressCss = () => {
  ()
  /*
    1. defines binding of postcss
    2. Do parallel async readFile css files
    3. Process css string with postcss using Promises.All
    4. Output ( copy them ) to the dist folder
  */
}

let run = () => {
  cleanDir("dist")
  copyAssets()
  generateHtml()
}
