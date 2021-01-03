type chokidar

type watchConfig = {
  ignored: string,
  persistent: bool,
}

@bs.module external watcher: chokidar = "chokidar"
@bs.send.pipe(: chokidar) external watch: (array<string>, watchConfig) => chokidar = "watch"
@bs.send.pipe(: chokidar) external on: (string, 'a => unit) => chokidar = "on"

let run = () => {
  let target = ["partials", "_pages", "_posts"]
  let config = {ignored: "*.bs.js", persistent: true}

  watcher
  |> watch(target, config)
  |> on("add", path => {
    Parser.run()
    Js.log(j`$path ditambahkan`)
  })
  |> on("change", path => {
    Parser.run()
    Js.log(j`$path diubah`)
  })
  |> on("unlink", path => {
    Parser.run()
    Js.log(j`$path dihapus`)
  })
}
