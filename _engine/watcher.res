type chokidar

type watchConfig = {
  ignored: Js.Re.t,
  persistent: bool,
}

@module external watcher: chokidar = "chokidar"
@send external watch: (chokidar, array<string>, watchConfig) => chokidar = "watch"
@send external on: (chokidar, string, 'a => unit) => chokidar = "on"

let run = () => {
  let target = ["partials", "_pages", "_posts"]
  let config = {ignored: %re("/^.*\.(bs.js)$/ig"), persistent: true}

  watcher
  -> watch(target, config)
  -> on("add", path => {
    Parser.run()
    Js.log(j`$path ditambahkan`)
  })
  -> on("change", path => {
    Parser.run()
    Js.log(j`$path diubah`)
  })
  -> on("unlink", path => {
    Parser.run()
    Js.log(j`$path dihapus`)
  })
}
