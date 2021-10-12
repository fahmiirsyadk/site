module H = Dust.Html.Elements
module A = Dust.Html.Attributes

type dataPost = { title : string }

type post =
  { content : string
  ; data : dataPost
  }

let main (post : post) =
  H.html
    []
    [ H.head
        []
        [ H.link [ A.rel_link `Stylesheet; A.href "/assets/css/styles.css" ] []
        ; H.title [] (H.text post.data.title)
        ]
    ; H.body
        [ A.class_ "bg-black" ]
        [ H.h1
            [ A.class_ "mx-auto text-center text-red-500 font-bold text-6xl" ]
            (H.text "Coming soon")
        ; H.div [] [ post.content ]
        ]
    ]
;;
