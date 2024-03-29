open Promise
@module external fsglob: array<string> => Promise.t<array<string>> = "fast-glob"
@scope("Object") @val external obj_entries: 'a => array<'a> = "entries"

type metadataML = {
  status: bool,
  filename: string,
  content: string,
  path: string,
}


type collectionMeta = {
  layout: string,
  source: string
}

module Config = Internal__Dust_Config
module Markdown = Internal__Dust_Markdown
module Utils = Internal__Dust_Utils

let globalMetadata: array<{.}> = []
let pagesPath = [Config.getFolderBase(), "pages"]->Node.Path.join
let pagePattern = [pagesPath, "**", "*.bs.js"]->Node.Path.join

let cleanOutputFolder = () => Utils.emptyDir(Config.getFolderOutput())

let generateHtml = (htmlContent, location) => {
  location->Utils.outputFile(
    htmlContent,
    ~options=Utils.writeFileOptions(~encoding="utf-8", ()),
    (),
  )
}

let parseCollection = (meta, output, filename, props): metadataML => {
  if Node.Fs.existsSync(meta["layout"]) {
    let process = %raw("
      function (meta, output, filename, props) {
        const res = require(`${meta.layout}`)

        const status = res.main ? true : false
        const filepath = Path.join(output, meta.name, Path.basename(filename, `.md`), `index.html`)
        
        if(status) {
          return { status, filename, path: filepath, content: res.main(props)}
        } else {
          return { status, filename, path: filepath, content: ``}
        }
    }")
    process(meta, output, filename, props)
  } else {
    let basename = Node.Path.basename(meta["layout"])->Js.String2.slice(~from=0, ~to_=-3)
    Utils.ErrorMessage.logMessage(Errors(`Template [${basename}] not exist`))
    Utils.ErrorMessage.logMessage(Info(`Create a file named ${basename}.ml in folder layouts`))
    {status: false, filename: filename, path: filename, content: ``}
  }
}

let parsePages = (metadata, path, output): metadataML => {
  if Node.Fs.existsSync(path) {
    Utils.readImportML(metadata, path, output)
  } else {
    let basename = Node.Path.basename(path)->Js.String2.slice(~from=0, ~to_=-3)
    Utils.ErrorMessage.logMessage(Errors(`Page [${basename}] not exist`))
    Utils.ErrorMessage.logMessage(Info(`Create a file named ${path}.ml in folder pages`))
    {status: false, filename: path, path: output, content: ``}
  }
}

let renderCollections = () => {
  let collectionMetadata = () =>
    Config.collections()
    ->obj_entries
    ->Js.Array2.map(collection => {
        let meta: collectionMeta = collection[1]
        {
        "name": collection[0],
        "layout": [Config.getFolderBase(), "layouts", meta.layout ++ ".bs.js"]
        ->Node.Path.join
        ->Node.Path.normalize,
        "source": [Config.rootPath, meta.source]->Node.Path.join->Node.Path.normalize,
        "pattern": [Config.rootPath, meta.source, "*.md"]
        ->Node.Path.join
        ->Node.Path.normalize,
        }
      }
    )

  let transformMeta = %raw("
      function(config, metadata, page, md, matter) {
        const newMatter = {...matter, content: md}
        const url = Path.join(`/`, metadata.name, Path.basename(page, `.md`))
        return {
          config: config,
          ...metadata,
          ...newMatter,
          url,
          page
        }
      }
    ")

  let proccessCollectionPages = metadata => {
    // Make sure globalMetadata valus are empty first
    let _ =
      globalMetadata->Js.Array2.removeCountInPlace(~pos=0, ~count=globalMetadata->Js.Array2.length)

    [metadata["pattern"]]
    ->fsglob
    ->then(pages => {
      pages
      ->Js.Array2.map(page => {
        Utils.readFile(page, "utf-8")->then(raw => {
          raw->Markdown.renderMarkdown
        })->then(data => {
          let matter = data["matter"]
          let html = data["html"]
          let config = switch Internal__Dust_Config.dataConfig {
            | Some(val) => val
            | None => ""
          }
          let props = transformMeta(config, metadata, page, html, matter)
          let _ = globalMetadata->Js.Array2.push(props)
          parseCollection(metadata, Config.getFolderOutput(), page, props)->resolve
        })
      })->resolve
    })
    ->then(eachFile => eachFile->Promise.all)
    ->then(collections => [collections]->Utils.flatten->resolve)
    ->then(collections =>
      collections
      ->Js.Array2.map(collection => collection.content->generateHtml(collection.path))
      ->Promise.all
    )
  }

  collectionMetadata()
  ->Js.Array2.map(metadata => {
    metadata->proccessCollectionPages
  })
  ->Promise.all
}

let sortGlobalCollectionMeta = %raw("
  function(metadata) {
    let obj = {};

    metadata.forEach(meta => {
      if(obj.hasOwnProperty(meta.name)) {
        obj[meta.name].push(meta)
      } else {
        obj[meta.name] = [meta]
      }
    })

    return obj
  }
")

let copyPublic = () => {
  let publicPath = Config.config.public
  publicPath->Node.Fs.existsSync
    ? publicPath->Utils.recCopy(
        Config.getFolderOutput(),
        {overwrite: true, dot: true, results: false},
      )
    : resolve()
}

let renderPage = (pagePath, metadata) => {
  let pageFilename = pagePath->Node.Path.basename_ext(".bs.js")
  let specialPage = switch pageFilename {
  | "index"
  | "404"
  | "500" => true
  | _ => false
  }

  let targetPath =
    pagePath
    ->Js.String2.replace(
      pageFilename,
      !specialPage ? [pageFilename, "index"]->Node.Path.join : pageFilename,
    )
    ->Js.String2.replace(".bs.js", ".html")
    ->Js.String2.replace(
      [Config.getFolderBase(), "pages"]->Node.Path.join,
      Config.getFolderOutput(),
    )

  let pages = metadata->sortGlobalCollectionMeta->parsePages(pagePath, targetPath)
  pages.status === true ? pages.content->generateHtml(pages.path) : ()->resolve
}

// first build
let run = () => {
  [pagePattern]
  ->fsglob
  ->then(paths => {
    let listRenderPages = () => paths->Js.Array2.map(path => renderPage(path, globalMetadata))

    if Config.isConfigExist {
      Utils.ensureDir(Config.getFolderOutput())->then(() => copyPublic())->ignore
      renderCollections()->then(_ => listRenderPages()->Promise.all)
    } else {
      Utils.ensureDir(Config.getFolderOutput())->then(() => copyPublic())->ignore
      listRenderPages()->Promise.all
    }
  })
}

// update
let update = path => {
  // Utils.checkCache()
  let replacePath = origin => origin->Js.String2.replace("src", "dist")
  let replacePathAndRemove = origin => origin->replacePath->Utils.remove

  // process pages
  let filename = path->Node.Path.basename

  let dataPagesTuple = (
    filename->Js.String2.includes(".md"),
    filename->Js.String2.includes(".ml"),
    path->Js.String2.includes(pagesPath),
  )

  switch dataPagesTuple {
  | (true, false, false) => path->replacePathAndRemove->then(_ => renderCollections())->ignore
  | (false, true, _) =>
    path
    ->replacePathAndRemove
    ->then(_ => renderCollections())
    ->then(_ => [pagePattern]->fsglob)
    ->then(pagesPath => pagesPath->Js.Array2.map(path => renderPage(path, globalMetadata))->resolve)
    ->ignore
  | _ =>
    switch path->Js.String2.includes("public") {
    | true => {
        let newPublicPath = path->Js.String2.replace(Node.Path.join2("src", "public"), "dist")
        newPublicPath->Utils.remove->then(_ => path->Utils.copy(newPublicPath))->ignore
      }
    | false => path->replacePathAndRemove->then(_ => path->Utils.copy(path->replacePath))->ignore
    }
  }
}
