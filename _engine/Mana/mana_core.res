module Core = {
  let render = (tag, attrs, children) => {
    let el =
      switch children {
      | list{} => ""
      | list{head, ...rest} => List.fold_left((a, b) => a ++ b, head, rest)
      }

    let at =
      switch attrs {
      | list{} => ""
      | list{head, ...rest} => List.fold_left((a, b) => j`$a$b`, head, rest)
      }
      
    j`<$tag$at>$el</$tag>`
  }
  let attrFormat = (attr: string, prop: string) => j` $attr="$prop"`
  let textAttr = (attr: string, prop: string): string => attrFormat(attr, prop)
  let boolAttr = (attr: string, prop: bool): string => prop->string_of_bool |> attrFormat(attr)
}
