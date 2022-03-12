module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

(* let surrealScript = 
  H.script [ A.type_ "module" ] [ E.inject "js/surreal.js" ] *)

  type matter = { title : string }

  type metadata =
    { name : string
    ; layout : string
    ; source : string
    ; data : matter
    ; excerpt : string
    ; url : string
    ; content : string
    }
  
  type sources = 
    { blog : metadata array
    ; projects: metadata array
    }

let mainWrapperStyle = "max-width: calc(100vw - (4rem * 2));"

let listMenuData sources =
  let blog = sources.blog |> Array.length in
  let projects = sources.projects |> Array.length in
  [
    ({j|Blog ($blog)|j}, "blog")
  ; ({j|Projects ($projects)|j}, "projects")
  ; ("About Me", "about")
  ; ("Resume", "resume")
  ]

let listMenu menu =
  menu |> List.map (fun (title, link) -> 
    H.li [ A.class_ "mb-2" ] [ 
      H.a [ A.class_ "font-medium hover:text-neutral-200"; A.href {j|/$link|j} ] [
        title
      ]
    ]
  )

let introduction = 
  H.div [ A.class_ "text-neutral-100" ] [
    H.h4 [ A.class_ "font-bold text-xl mb-4 uppercase leading-none" ] ["Fahmi Irsyad Khairi"]
  ; H.p [ A.class_ "max-w-lg text-neutral-400"] [
      "Web developer / full-time frontend developer based in Indonesia, <strong>passionate</strong>
      about <strong>experiment</strong> with things, build <strong>solid</strong> <strong>performant</strong> creative software."
    ]
  ]

let mainWrapper sidebar main = 
  H.section [ A.class_ "flex mx-auto pt-16"; A.style mainWrapperStyle ] [
    sidebar
  ; main
  ]

let sidebarContent sources = 
  H.aside [] [
    H.div [ A.class_ "mb-6"; ] [
      Logo.logo 70 "#f5f5f5"
    ]
  ; H.h1 [ A.class_ "text-neutral-100 font-swear italic text-5xl" ] [
      {js|Fa—h.|js}
    ]
  ; H.ul [ A.class_ "text-neutral-400 mt-6" ] (
      listMenu (listMenuData sources)
    )
  ]

let mainContent sources =
  let blog = sources.blog |> Array.to_list in
  let projects = sources.projects |> Array.to_list in
  let processArticle source = 
    source |> List.map (fun meta ->
      H.li [ A.class_ "text-neutral-200 mb-4"] [
        H.a [ A.class_ "group"; A.href meta.url ] [
          H.h6 [ A.class_ "group-hover:underline font-semibold" ] [ meta.data.title ]
        ; H.p [ A.class_ "text-sm text-neutral-400 mt-1" ] [ meta.excerpt ]
        ]
      ]      
    ) 
  in
  H.div [ A.class_ "px-28" ] [
    introduction
  ; H.div [ A.class_ "flex w-lg justify-between space-x-4 mt-8" ] [
      H.div [ A.class_ "w-64" ] [
        H.h5 [ A.class_ "font-swear italic text-neutral-100 text-xl mb-4" ] [ "Recent article" ]
      ; H.ul [] (processArticle blog)
      ]
    ; H.div [ A.class_ "w-64" ] [
        H.h5 [ A.class_ "font-swear italic text-neutral-100 text-xl mb-4" ] [ "Recent project" ]
      ; H.ul [] (processArticle projects)
      ]
    ]
  ]

let main sources =
  H.html [] [
    Seo.head ~children: "" ()
  ; H.body [ A.class_ "bg-black"] [
      H.main [ A.class_ "min-h-screen relative"] [
        mainWrapper (sidebarContent sources) (mainContent sources)
      ]
    ; Footer.elem
    ]
  ]