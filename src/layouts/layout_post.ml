module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let footer = Partial_footer.footer :: Layout_app.script
let head title = Partial_head.head ~title:(title ^ " -- Fahmiirsyadk")
let body ctx = H.body [] 
  ( H.div [ P.class_ "container" ] [
      H.a [
        P.href "/"
      ] (H.text "Home");
      ctx;
    ] :: footer )

let template content (meta: Parser.metadata) =  
  H.html [P.lang "en"] [
    head meta.matter.title;
    body content;
  ]