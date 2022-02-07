let combine_elem elem list =
  list |. Belt.List.reduce "" (fun a b -> let (k, v) = b in a ^ elem k v)