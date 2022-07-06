
let splitCodeBlock (str: string) =
  [%re {|/<pre\b[^>]*>(.*)<\/pre>/s|}]
  |. Js.Re.exec_ str
  |> function
    | Some result -> 
      let _ = Js.log (result) in
      Js.Nullable.toOption (Js.Re.captures result).(1)
    | None -> None

let getString (text: string): string option =
  let regex = [%re {|/\{([^)]+)\}/|}] 
  |. Js.Re.exec_ text 
  |> function
    | Some result -> 
      Js.Nullable.toOption (Js.Re.captures result).(1) 
    | None -> None
in
  let isMatch = [| "@@highlights"; "@@focus"; "@@errors"; "@@warnings"; "@@filename" |]
  |> Js.Array.filter (fun x -> Js.String2.includes text x)
in
  (* check if isMatch array is empty or not *)
  match (Js.Array2.length isMatch) > 0 with
  | true -> regex
  | false -> None