type chokidar
type server

type watchConfig = {
  ignored: Js.Re.t,
  persistent: bool,
  ignoreInitial: bool
}

type serverConfig = {
  root: string,
  logLevel: int
}

@module external watcher: chokidar = "chokidar"
@send external watch: (chokidar, array<string>, watchConfig) => chokidar = "watch"
@send external on: (chokidar, string, 'a => unit) => chokidar = "on"
@val @scope("console") external clear: unit => unit = "clear"
@module external server: server = "live-server"
@send external start: (server, serverConfig) => unit = "start"
  
let exec = () => {  
  let _ = Node.Child_process.execSync("npm run compile", Node.Child_process.option(~cwd=Node.Process.cwd(), ~encoding="utf-8", ()))
}

let run = () => {
  server->start({ root: Node.Process.cwd() ++ "/dist", logLevel: 0 })
  clear()
  Js.log("Ready for changes")
  let target = ["src/components", "src/pages", "src/posts", "src/assets", "src/layouts"]
  let config = {
    ignored: %re("/^.*\.(mjs)$/ig")
      , persistent: true
      , ignoreInitial: true
  }

  watcher
  -> watch(target, config)
  -> on("add", path => {
    exec()
    Js.log(j`$path ditambahkan`)
  })
  -> on("change", path => {
    exec()
    Js.log(j`$path diubah`)
  })
  -> on("unlink", path => {
    exec()
    Js.log(j`$path dihapus`)
  })
}
