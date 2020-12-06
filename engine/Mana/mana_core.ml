module Core =
struct
  let render tag attrs children =
    let el =
      match children == [] with
      | true  -> ""
      | false  ->
        List.fold_left (fun a  -> fun b  -> a ^ b) (List.hd children)
          (List.tl children) in
    let at =
      match attrs == [] with
      | true  -> ""
      | false  ->
        List.fold_left (fun a  -> fun b  -> {j|$a $b|j}) (List.hd attrs)
          (List.tl attrs) in
    {j|<$tag $at>$el</$tag>|j}
  let attrFormat (attr : string) (prop : string) = {j|$attr="$prop"|j}
  let textAttr (attr : string) (prop : string) =
    (attrFormat attr prop : string)
  let boolAttr (attr : string) (prop : bool) =
    ((prop |. string_of_bool) |> (attrFormat attr) : string)
end
