module H = Mana.HTML
module P = Mana.Property

let styles = Mana.Extra.inject("src/assets/css/offline.css")
let head =
  H.head [
  ] [
    H.meta [P.charset "UTF-8"] [];
    H.title [] (H.text "Fahmiirsyadk");
    H.style [] (H.text styles);
  ]

let body = 
  H.body [] [
    H.section [] [
      H.h2 [] 
        ("This experience is only available with internet connection" |> H.text)
    ]
  ]  

let html () =
  H.html [] [
    head;
    body;
  ]