let command = Node_process.argv[2]

/* using ordinary ADT, it's just running sideeffect */
type t<'a, 'b> =
  | Build('a)
  | Watch('b)

let run = ((x, y)) =>
  switch command {
  | "build" => Build(x())
  | "watch" => Watch(y())
  | _ => invalid_arg("invalid command")
  }

let _ = run((Parser.run, Watcher.run))
