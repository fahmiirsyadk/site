let combineElement2 elem list =
  list |. Belt.List.reduce "" (fun a b -> let (k, v) = b in a ^ elem k v)

let combineElement elem list =
  list |. Belt.List.reduce "" (fun a b -> a ^ elem b)

let combineElement3 elem list =
  list |. Belt.List.reduce "" (fun a b -> let (k, v, c) = b in a ^ elem k v c)
  

let rec merge = function 
  | x::xs -> (function y::ys -> x::y::merge xs ys | [] -> x::xs)
  | [] -> function ys -> ys