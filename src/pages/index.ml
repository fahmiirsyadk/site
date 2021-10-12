module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let main () =
  H.html
    [] [ 
      Seo.head ()
    ; H.body
        []
        [ H.h1
            [ A.class_ "mx-auto text-center text-purple-500 font-bold text-6xl mt-12" ]
            (H.text "Coming soon")
        ; H.p [] (H.text "ini deskripsi")
        ; H.img [ A.class_ "mx-auto"; A.src "/assets/images/makima.png"; A.alt "makima god" ] []
        ; H.a
            [ A.href "/blog"
            ; A.class_ "text-6xl mt-10 text-green-500 font-bold text-center underline"
            ]
            [ H.span [] (H.text "Klik disini untuk blog") ]
        ]
    ]
;;
