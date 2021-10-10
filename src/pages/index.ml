module H = Dust.Html.Elements
module P = Dust.Html.Properties

let main () = 
  H.html [] [
    H.link [
      P.rel__link `Stylesheet;
      P.href "/assets/css/styles.css";
    ] [];
    H.body [] [
      H.h1 [ P.class_ "mx-auto text-center text-purple-500 font-bold text-6xl mt-12" ] (H.text "Coming soon");
      H.p [] (H.text "ini deskripsi");
      H.img [
        P.src "/assets/images/makima.png";
        P.alt "makima god"
      ] []
    ]
  ]