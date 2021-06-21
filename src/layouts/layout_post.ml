module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let footer = Partial_footer.footer
let head title = Partial_head.head ~title:(title ^ " -- Fahmiirsyadk")
let body ctx = H.body [] ( ctx :: footer :: Layout_app.script )
let template content (meta: Parser.metadata) =  
  H.html [P.lang "en"] [
    head meta.matter.title;
    body content;
  ]