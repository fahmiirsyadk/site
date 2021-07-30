type htmlTagType =  Single | Paired
let render: (htmlTagType, string, list<string>, list<string>) => string
type renderAttr =  String | Variant
let attrFormat: (string, 'a) => string
let textAttr: (string, string) => string
let boolAttr: (string, bool) => string