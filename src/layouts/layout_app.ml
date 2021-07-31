module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let footer = Partial_footer.footer

let navigation =
  H.header [] [
      H.nav [] (H.text "navigation")
  ]
let themeJS = E.inject "src/assets/js/theme.min.js"

let script = [
  H.script [] [ themeJS ];
  H.script [
    P.async "";
    P.src "/assets/js/main.min.js"
  ] [];
]

let layout head section =
  H.html [ P.lang "en" ] (
    head ::
    H.body [] [
      H.div [ P.class_ "container" ] [
        section;
        footer;
      ]
    ] :: script )

(* Because the homepage is more _weird_ than other page, so footer must be removed *)
let layout_index head section =
  H.html [ P.lang "en" ] (
    head ::
    H.body [] [
      section
    ] :: script)