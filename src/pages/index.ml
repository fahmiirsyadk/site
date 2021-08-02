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
      H.div [ P.class_ "hero-content__title"] [
        H.div [ P.class_ "title-wrapper" ] [
        H.div [ P.style "display: flex;"] [
          H.span [] (H.text "Push the&nbsp;"); 
          H.span [ P.class_ "hero-content__footprint" ]
            (H.text "Fahmi is Front-end developer Based in Banyuwangi, Indonesia");
        ]; 
          H.p [ P.style "color: #FFE7CA; font-size: 9.25vw"] [ H.i [] (H.text "Boundaries")];
        ];
      ];
      H.div [ P.class_ "hero-content__image"] [
        H.div [ P.class_ "hero-content__borderline" ] [];
        H.pre [] (H.text AppConfig.Data.ascii)
      ];
    ]
  ]

let headerNav = 
  H.nav [ P.class_ "navbar" ] [
    H.div [ P.class_ "navbar__logo"] (H.text AppConfig.SEO.title);
    H.ul [ P.class_ "navbar__menu"] [
      H.li [] (H.text "Blog");
      H.li [] (H.text "Project");
      H.li [] (H.text "About");
    ];
    H.div [ P.class_ "navbar__toggle" ] [
      H.div [] (H.text "button_toggle")
    ];
  ]

let body posts =
  H.div [] [
    headerNav;
    H.section [ P.class_ "container" ] [
      hero;
      H.div [] (listPost posts);
    ]
  ]

(* render *)
let main (posts: Parser.metadata array) =
  App.layout_index (Partial_head.head ~title: AppConfig.SEO.title) (body posts)