let command = (Array.get Node_process.argv 2)

let _ = match command with
  | "build" -> Parser.run()
  | _ -> Js.log "wrong command"
