let serializeCollection collection =
  let arr = [| collection |] in
  let flatten = [%raw  "function (arr) { return arr.flat()}"] in

  match arr |> Js.Array.length with
  | 0
  | 1 -> flatten arr |> Array.to_list
  | _ -> collection |> Array.to_list

let combine_elem elem list =
  list |. Belt.List.reduce "" (fun a b -> let (k, v) = b in a ^ elem k v)