module H = Mana.HTML
module P = Mana.Property

let footer = Partial_footer.footer

let navigation =
  H.header [] [
      H.nav [] (H.text "navigation")
  ]

let layout head section =
    H.html [ P.language "en" ] [
        head;
        H.body [] [
            section;
            footer;
        ]
    ]
