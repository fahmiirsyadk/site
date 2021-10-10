module H = Dust.Html.Elements
module P = Dust.Html.Properties

type dataPost = {
  title: string
}

type post = {
  content: string;
  data: dataPost
}

let main (post: post) = 
  H.html [] [
    H.head [] [
      H.link [
        P.rel__link `Stylesheet;
        P.href "/assets/css/styles.css";
      ] [];
      H.title [] (H.text post.data.title);
    ];
    H.body [
      P.class_ "bg-black"
    ] [
      H.h1 [ P.class_ "mx-auto text-center text-red-500 font-bold text-6xl" ] (H.text "Coming soon");
      H.div [] [
        post.content
      ]
    ]
  ]