module H = Mana.HTML
module P = Mana.Property

module App = Layout_app

let listPost posts =
  Belt.List.map (Array.to_list posts)
    (fun (post: Parser.metadata) ->
       H.a [
         P.href post.url;
       ] [
         H.li [] (H.text post.matter.title);
       ]
    )

(* Variables *)
let heading_title =
    "Hi, i’m fahmi. On this site you will literally find collection of poetries, notes, thoughts, or anything comes up into my mind. " 

let body posts =
  H.section [] [
   H.button [
    (P.id "theme-toggle");
    (P.type_ "button");
   ] [
    H.span [] (H.text "moon");
    H.span [] (H.text "shine");
   ];
    H.div [ (P.class_ "section-home") ] [
        H.div [ (P.class_ "section-home__left") ] [
            H.div [ P.class_ "circle-blur circle-blur-red" ] [];
            H.div [ (P.class_ "hero-heading") ] [
                H.h1 [ P.class_ "hero-heading__title" ] [
                    H.span [] ( H.text "The Space ");
                    H.span [ P.style "font-style: italic;" ] (H.text "Garden.");
                ];
                H.div [ P.class_ "hero-heading__desc" ] [
                    H.span [] (H.text heading_title);
                    H.a [ P.href "/about"] (H.text "More about me -->");
                ];
            ];
        ];
        H.div [ (P.class_ "section-home__right") ] [            
            H.h1 [] (H.text "Recent article");
            H.ol [] (listPost posts);
        ];
    ];
  ]

let html (posts: Parser.metadata array) =
  App.layout (Partial_head.head ~title: "blog") (body posts)
