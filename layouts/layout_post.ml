module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let footer = Partial_footer.footer
let css = E.inject "assets/css/style.css"

let template content (meta: Parser.metadata) =  
  [
  H.head [] [
    H.link [
      P.rel "preconnect";
      P.href "https://fonts.gstatic.com";
    ] [];
    H.link [
      P.href "https://fonts.googleapis.com/css2?family=Merriweather:ital,wght@0,400;0,700;1,400&display=swap";
      P.rel "stylesheet";
    ] [];
    H.title [] (H.text meta.matter.title);
    H.meta [
      (P.name "description");
      (P.content ("from layout - " ^ meta.matter.title))
    ] [];
    H.style [] (H.text css);
  ]; H.body [] [
    content;
    footer;
  ]] |> H.html [ P.lang "en" ]
