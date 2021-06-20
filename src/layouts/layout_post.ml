module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let footer = Partial_footer.footer
let head = Partial_head.head

let template content (meta: Parser.metadata) =  
  [
  H.head [] [
    head ~title:(meta.matter.title ^ " -- Fahmiirsyadk");   
  ]; H.body [] [
    content;
    footer;
  ]] |> H.html [ P.lang "en"]
