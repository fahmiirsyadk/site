/* start logging time */
/* delete previous build folder */
/* create blog folder */
/* get all pages & posts data */
/* get page filename ( used for invidual html page ) */
/* get graymatter data */
/* passing gray matter to pages files */
/* parse markdown to html */
/* passing data markdown (html) to blogpost file */
/* parse data pages (.ml) to html */
/* send to the output dir */
/* parse individual blog post file & send them to the output blog dir */
/* end logging time */

type typeMatter = {
  title: string,
  date: string,
  template: option<string>,
}

type metadata = {
  filename: string,
  url: string,
  content: string,
  matter: typeMatter,
  excerpt: string,
}

type graymatter = {
  content: string,
  data: typeMatter,
  isEmpty: bool,
  excerpt: string,
}

type matterAndPath = {
  matter: graymatter,
  path: string,
}
open Utils.NodeJS.Path
module Extra = Utils.Fs_Extra
module Path = Node.Path
module Process = Utils.NodeJS.Process
@bs.module external matter: string => 'a = "gray-matter"

let outDir = "dist"->Path.join2(Process.cwd(Process.process))->Path.normalize

let cleanDir = (path: string) =>
  path->Utils.NodeJS.Path.join2(Process.cwd(Process.process))->Path.normalize->Extra.removeSync

let getGlob = (path: array<string>) => path->Path.join->Path.normalize->Utils.glob

let getPages: array<string> = [Process.cwd(Process.process), "_pages", "**", "*.ml"]->getGlob
let getPosts: array<string> = [Process.cwd(Process.process), "_posts", "**", "*.md"]->getGlob

/* markdown */
let processMd: array<(string, string)> = Belt.Array.map(getPosts, x => (
  Extra.readFileSync(x, "utf8"),
  x,
))

let processMatter: array<matterAndPath> = Belt.Array.map(processMd, ((x, y)) => {
  matter: matter(x),
  path: y,
})

let sortMatterByDate =
  processMatter->Js.Array2.sortInPlaceWith((a, b) =>
    a.matter.data.date < b.matter.data.date ? 1 : -1
  )

let parseMarkdown = content =>
  Utils.remark()
  |> Utils.use(Utils.remarkFootnotes)
  |> Utils.use(Utils.remarkImages)
  |> Utils.use(Utils.remarkToc)
  |> Utils.use(Utils.remarkHtml)
  |> Utils.processSync(content)

let metadataPost = (matter: graymatter, path) => {
  filename: "name",
  url: "blog/" ++ path->basenameNoExt(".md"),
  content: matter.content |> parseMarkdown,
  excerpt: matter.excerpt,
  matter: matter.data,
}

let createMetaData: array<metadata> =
  sortMatterByDate->Js.Array2.map((post: matterAndPath) => post.matter->metadataPost(post.path))

let importManaFile = %raw(`
  function(path, props) {
    let data = require(path);
    return data.html(props);
  }
`)

/* blogpost */
let generatePosts = () =>
  Belt.Array.forEach(createMetaData, (meta: metadata) => {
    let basename = basenameNoExt(meta.url, ".md")
    let blogpostPath = Path.join([Process.cwd(Process.process), "_pages", "blogpost" ++ ".bs.js"])
    importManaFile(blogpostPath, meta)->Extra.outputFileSync(
      j`dist/blog/$basename/index` ++ ".html",
    )
  })

let generatePages = () =>
  Belt.Array.forEach(getPages, path => {
    let basename = basenameNoExt(path, ".ml")
    switch basename {
    | "blogpost" => generatePosts()
    | _ =>
      Path.join([Process.cwd(Process.process), "_pages", basename ++ ".bs.js"])
      ->Path.normalize
      ->importManaFile(createMetaData)
      ->Extra.outputFileSync(j`dist/$basename` ++ ".html")
    }
  })

let run = _ => {
  cleanDir("dist")
  generatePages()
}
