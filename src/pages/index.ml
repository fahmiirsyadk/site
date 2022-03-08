module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

(* let surrealScript = 
  H.script [ A.type_ "module" ] [ E.inject "js/surreal.js" ] *)

let mainContentStyle = "max-width: calc(100vw - (4rem * 2));"
let listMenuData =
  [
    ("Blog", "blog")
  ; ("Projects", "projects")
  ; ("Notes", "notes")
  ; ("About Me", "about")
  ]
let listMenu menu =
  menu |. Belt.List.map (fun (title, link) -> 
    H.li [ A.class_ "mb-2" ] [ 
      H.a [ A.class_ "font-medium hover:text-zinc-300"; A.href {j|/$link|j} ] [
        title
      ]
    ]
  )

let mainContent = 
  H.section [ A.class_ "flex mx-auto pt-16"; A.style mainContentStyle ] [
    H.aside [] [
      H.div [ A.class_ "mb-6"; ] [
        Logo.logo 70 "white"
      ]
    ; H.h1 [ A.class_ "text-white font-swear italic text-5xl" ] [
        {js|Fa—h.|js}
      ]
    ; H.ul [ A.class_ "text-zinc-500 mt-6" ] (
        listMenu listMenuData
      )
    ]
  ]

let main () =
  H.html [] [
    Seo.head ~children: "" ()
  ; H.body [ A.class_ "bg-black"] [
      H.main [ A.class_ "min-h-screen relative"] [
        mainContent
      ]
    ; Footer.elem
    ; H.canvas [ A.id "canvasme"; ] []
    ]
  ]