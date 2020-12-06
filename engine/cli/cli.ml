let command = (Array.get Node_process.argv 2)

let _ = match command with
  | "build" -> Node_fs.writeFileSync "demo.html" Demo.html `utf8
  | _ -> Js.log "wrong command"
