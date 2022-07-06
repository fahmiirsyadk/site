let combine_elem elem list =
  list |. Belt.List.reduce "" (fun a b -> let (k, v) = b in a ^ elem k v)

let rec merge = function 
  | x::xs -> (function y::ys -> x::y::merge xs ys | [] -> x::xs)
  | [] -> function ys -> ys