module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

(* let surrealScript = 
  H.script [ A.type_ "module" ] [ E.inject "js/surreal.js" ] *)

let mainWrapperStyle = "max-width: calc(100vw - (4rem * 2));"

let listMenuData =
  [
    ("Blog (10)", "blog")
  ; ("Projects (2)", "projects")
  ; ("About Me", "about")
  ; ("Resume", "resume")
  ]
let listMenu menu =
  menu |. Belt.List.map (fun (title, link) -> 
    H.li [ A.class_ "mb-2" ] [ 
      H.a [ A.class_ "font-medium hover:text-zinc-300"; A.href {j|/$link|j} ] [
        title
      ]
    ]
  )

let introduction = 
  H.div [ A.class_ "text-white" ] [
    H.h4 [ A.class_ "font-bold text-xl mb-4 uppercase leading-none" ] ["Fahmi Irsyad Khairi"]
  ; H.p [ A.class_ "max-w-lg text-zinc-500"] [
      "Web developer / full-time frontend developer based in Indonesia, <strong>passionate</strong>
      about <strong>experiment</strong> with things, build <strong>solid</strong> <strong>performant</strong> creative software."
    ]
  ]

let mainWrapper sidebar main = 
  H.section [ A.class_ "flex mx-auto pt-16"; A.style mainWrapperStyle ] [
    sidebar
  ; main
  ]

let sidebarContent = 
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

let mainContent = 
  H.div [ A.class_ "px-28" ] [
    introduction
  ; H.div [ A.class_ "flex w-lg justify-between space-x-4 mt-8" ] [
      H.div [ A.class_ "w-64" ] [
        H.h5 [ A.class_ "font-swear italic text-white text-xl mb-4" ] [ "Recent article" ]
      ; H.ul [] [
          H.li [ A.class_ "text-zinc-300 mb-4" ] [
            H.a [ A.href "/blog/deconstruct-site" ] [ 
              H.h6 [] ["Deconstruct site"]
            ; H.p [ A.class_ "text-sm text-zinc-600 mt-1" ] [ "Explaining why & how this site born." ]
             ]
          ]
        ; H.li [ A.class_ "text-zinc-300 mb-4" ] [
            H.a [ A.href "/blog/deconstruct-site" ] [ 
              H.h6 [] [ "First approach learning web3" ]
            ; H.p [ A.class_ "text-sm text-zinc-600 mt-1" ] [ "My first step touching web3, like solidity." ]
             ]
          ]
        ]
    ]
    ; H.div [ A.class_ "w-64" ] [
        H.h5 [ A.class_ "font-swear italic text-white text-xl mb-4" ] [ "Recent project" ]
      ; H.ul [] [
          H.li [ A.class_ "text-zinc-300" ] [
            H.a [ A.href "/blog/deconstruct-site" ] [ 
              H.h6 [] [ "Dust" ]
            ; H.p [ A.class_ "text-sm text-zinc-600 mt-1" ] [ "Static site generator with OCaml/Rescript Syntax." ]
             ]
          ]
        ]
      ]
    ]
  ]

let main () =
  H.html [] [
    Seo.head ~children: "" ()
  ; H.body [ A.class_ "bg-black"] [
      H.main [ A.class_ "min-h-screen relative"] [
        mainWrapper sidebarContent mainContent
      ]
    ; Footer.elem
    ]
  ]