module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

let desc = "Web developer / full-time frontend developer based in Indonesia, passionate to experiment with things, build solid & performant creative software."
let main () =
  H.html [] [
    Seo.head ~children:"" ()
  ; H.body [] [
      H.main [ A.class_ "max-w-5xl mx-auto min-h-screen"] [
        H.header [ A.class_ "text-center"] [
          H.div [
            A.class_ "position-absolute left-0 top-0 w-100 h-64"
          ; Aria.ariaHidden "true"
          ] []
        ; H.h1 [ A.class_ "font-bold font-swear text-3xl mb-8"] (H.text "Fahmi Irsyad Khairi")
        ; H.p [ A.class_ "px-64"] (H.text desc)
        ]
      ]
    ; Footer.elem
    ]
  ]
