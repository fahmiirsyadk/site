module Core = {
  let render = (tag, attrs, children) => {
    let el =
      children === list{}
        ? ""
        : List.fold_left((a, b) => a ++ b, List.hd(children), List.tl(children))
    let at =
      attrs === list{} ? "" : List.fold_left((a, b) => j`$a$b`, List.hd(attrs), List.tl(attrs))
    j`<$tag$at>$el</$tag>`
  }
  let attrFormat = (attr: string, prop: string) => j` $attr="$prop"`
  let textAttr = (attr: string, prop: string): string => attrFormat(attr, prop)
  let boolAttr = (attr: string, prop: bool): string => prop->string_of_bool |> attrFormat(attr)
}
