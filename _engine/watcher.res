type chokidar

type watchConfig = {
  ignored: Js.Re.t,
  persistent: bool,
  ignoreInitial: bool
}

@module external watcher: chokidar = "chokidar"
@send external watch: (chokidar, array<string>, watchConfig) => chokidar = "watch"
@send external on: (chokidar, string, 'a => unit) => chokidar = "on"
@val @scope("console") external clear: unit => unit = "clear";

let exec = () => {  
  let _ = Node.Child_process.execSync("npm run compile", Node.Child_process.option(~cwd=Node.Process.cwd(), ~encoding="utf-8", ()))
}

let run = () => {
  clear();
  Js.log("waiting for changes...");
  let target = ["partials", "_pages", "_posts", "assets"]
  let config = {
    ignored: %re("/^.*\.(bs.js)$/ig")
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
