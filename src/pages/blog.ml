module H = Dust.Html.Elements
module P = Dust.Html.Properties

type matter = {
  title: string
}

type blog = { 
  name: string;
  layout: string;
  source: string;
  data: matter;
  excerpt: string;
  url: string;
  content: string
}

type posts = { blog: blog array }

let listPost posts =
  posts |. Belt.Array.map (fun post -> 
    H.div [] [
      H.a [
        P.href post.url
      ] [
        H.h1 [] (H.text post.data.title);
      ];
    ]) |> Array.to_list

let main (posts: posts) =
  H.html [] [
    H.body [] [
      H.p [] (H.text "blog test");
      H.div [] (listPost posts.blog)
    ]
  ]