@scope("Object") @val external obj_keys: 'a => array<'a> = "keys"
open Internal__Dust_Engine
open Promise

module Config = Internal__Dust_Config

let outputPath = Config.config.output
let startPath = [Config.rootPath, "src" ]->Node.Path.join->Node.Path.normalize
let buildSrc = [Config.rootPath, "_build", "default", "src" ]->Node.Path.join->Node.Path.normalize

let initialScript = () => {
  cleanOutputFolder()->then(_ => run())
}

let serverRun = () => {
  open Utils.Chokidar

  let config = {
    ignored: [
      buildSrc ++ "/**/*.cmi",
      buildSrc ++ "/**/*.cmt",
      buildSrc ++ "/**/*.cmj",
      buildSrc ++ "/**/*.ast",
      buildSrc ++ "/**/*.d",
    ],
    ignoreInitial: true,
    awaitWriteFinish: {
      stabilityThreshold: 100,
      pollInterval: 100
    },
    depth: 99
  }

  watcher
  ->watch(buildSrc, config)
  ->on("add", path => {
    Js.log("adding: " ++ path)
    initialScript()->ignore
  })
  ->on("change", path => {
    Js.log("changing: " ++ path)
    update(path)
  })
}

let watcher = () => {
  open Utils.LiveServer
  server->start({root: outputPath, logLevel: 0, opens: Config.config.openBrowser })
  Js.log("Ready for changes")
  serverRun()
}

let exec = () => {
  let command = try {
    Node.Process.argv[2]
  } catch {
  | Invalid_argument(_) => ""
  }

  switch command {
  | "watch"
  | "w" =>
    initialScript()
    ->then(_ => {
      let _ = watcher()
      resolve()
    })
    ->catch(err => Js.log(err)->resolve)
    ->ignore
  | _ => initialScript()->ignore
  }
}
