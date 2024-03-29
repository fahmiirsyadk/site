@module("fs") external existsSync: string => bool = "existsSync"
@module("js-yaml") external yamlLoad: string => 'a = "load"

type folderConfig = {
  output: string,
  base: string,
  openBrowser: bool,
  public: string,
  syntaxThemeUrl: string
}

let rootPath = Node.Process.cwd()
let configPath = [rootPath, ".dust.yml"]->Node.Path.join->Node.Path.normalize

let defaultConfig = {
  output: [rootPath, "dist"]->Node.Path.join->Node.Path.normalize,
  base: [rootPath, "_build", "default", "src" ]->Node.Path.join->Node.Path.normalize,
  public: [rootPath, "src", "public"]->Node.Path.join->Node.Path.normalize,
  openBrowser: true,
  syntaxThemeUrl: "nord"
}

let isConfigExist = configPath->existsSync

let dataConfig = {
  if configPath->existsSync {
    configPath->Node.Fs.readFileSync(#utf8)->yamlLoad->Js.toOption
  } else {
    Js.Nullable.null->Js.toOption
  }
}

let dustConfig = () => {
  switch dataConfig->Belt.Option.flatMap(content => content["dust"]) {
  | Some(config) => config
  | None => Js.Nullable.null
  }->Js.toOption
}

let getFolderBase = () => {
  switch dustConfig()->Belt.Option.flatMap(data => data["base"]) {
  | Some(val) => val
  | None => defaultConfig.base
  }
}

let getFolderOutput = () => {
  switch dustConfig()->Belt.Option.flatMap(data => data["output"]) {
  | Some(val) => val
  | None => defaultConfig.output
  }
}

let getOpenBrowser = () => {
  switch dustConfig()->Belt.Option.flatMap(data => data["openBrowser"]) {
  | Some(val) => val
  | None => defaultConfig.openBrowser
  }
}

let getSyntaxThemeUrl = () => {
  switch dustConfig()->Belt.Option.flatMap(data => data["syntaxThemeUrl"]) {
  | Some(val) => val
  | None => defaultConfig.syntaxThemeUrl
  }
}

let config = {
  base: getFolderBase(),
  output: getFolderOutput(),
  public: defaultConfig.public,
  openBrowser: getOpenBrowser(),
  syntaxThemeUrl: getSyntaxThemeUrl()
}

let collections = () => {
  switch dataConfig->Belt.Option.flatMap(content => content["collections"]) {
  | Some(collections) => collections
  | None => []
  }
}
