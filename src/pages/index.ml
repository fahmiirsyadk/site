module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let main () =
  H.html [] [ 
    Seo.head ~children:"" ()
  ; H.body [] [
      H.h1 [ A.class_ "text-center text-5xl font-medium"] (H.text "Blog")
    ]
  ]
