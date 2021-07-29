module H = Mana.HTML
module P = Mana.Property
module App = Layout_app

let listPost posts =
  Belt.List.map (Array.to_list posts)
    (fun (post: Parser.metadata) ->
       H.a [
         P.href post.url;
       ] [
         H.p [] (H.text post.matter.title);
       ]
    )

(* element hero *)
let hero = 
  H.div [ P.class_ "hero-container"] [
    H.div [ P.class_ "hero-content"] [
      H.img [] [];
      H.div [ P.class_ "hero-content__borderline" ] [];
      H.div [ P.class_ "hero-content__title"] [
        H.span [] (H.text "Push The Boundary");
        H.span [ P.class_ "title-overlay"] (H.text "&");
        H.span [] (H.text "Living Edge");
      ];
      H.div [ P.class_ "hero-content__footprint" ] [
        H.p [] (H.text "Frontend Developer");
        H.p [] (H.text "Based in Banyuwangi, Indonesia");
      ];
    ]
  ]
let body posts =
  H.section [] [
    H.div [ P.class_ "hero-container" ] [
      hero;
      H.div [] (listPost posts);
    ]
  ]

(* render *)
let html (posts: Parser.metadata array) =
  App.layout_index (Partial_head.head ~title: AppConfig.SEO.title) (body posts)