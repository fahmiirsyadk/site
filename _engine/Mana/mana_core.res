module Core = {
  let render = (tagType: Mana_types.htmlTagType, tag, attrs, children) => {
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

    let checkTagHTML = (template, tag) =>
      switch (tag === "html") {
      | true => j`<!DOCTYPE html>$template`
      | false => template
      }
      
      switch (tagType) {
      | Single => j`<$tag$at>`->checkTagHTML(tag)
      | Paired => j`<$tag$at>$el</$tag>`->checkTagHTML(tag)    
      }
    }

  type renderAttr =
    | String
    | Variant

  let attrFormat = (attr: string, prop: 'a) => j` $attr="$prop"`
  let textAttr = (attr: string, prop: string): string => attrFormat(attr, prop)
  let textAttrPoly = (attr: string, prop) => attrFormat(attr, prop)
  let boolAttr = (attr: string, prop: bool): string => prop->string_of_bool |> attrFormat(attr)
}
