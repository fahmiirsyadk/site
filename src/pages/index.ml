module H = Dust.Html.Elements
module P = Dust.Html.Properties

let main () = 
  H.html [] [
    H.body [] [
      H.h1 [] (H.text "Coming soon")
    ]
  ]