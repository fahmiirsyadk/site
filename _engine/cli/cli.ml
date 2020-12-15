let command = (Array.get Node_process.argv 2)

(* using ordinary ADT, it's just running sideeffect *)
type ('a, 'b) t =
  | Build of ('a)
  | Watch of ('b)

let run (x,y) = match command with
  | "build" -> Build (x())
  | "watch" -> Watch (y())
  | _ -> invalid_arg "invalid command"

let _ = run(Parser.run, Watcher.run)
