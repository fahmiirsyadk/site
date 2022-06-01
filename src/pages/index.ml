module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

type caption = 
| None
| Some of string

type matter = { title : string; caption: caption }

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


let styles = [%bs.obj {
  body = A.class_ "bg-neutral-900 selection:bg-orange-500 selection:text-black";
  mainWrapperRaw = (A.style "max-width: calc(100vw - (4rem * 2))");
  mainWrapper = A.class_ "flex mx-auto py-16";
  menuItemLink = A.class_ "font-medium hover:text-orange-400";
  headingTitle = A.class_ "font-bold text-xl mb-4 uppercase leading-none";
  headingDesc = A.class_ "max-w-lg text-neutral-400";
  sidebarTitle = A.class_ "text-neutral-100 font-swear italic text-5xl";
  sidebarMenu = A.class_ "text-neutral-400 mt-6";
  mainContentItemTitle = A.class_ "group-hover:underline group-hover:underline-offset-2 font-medium";
  mainContentItemCaption = A.class_ "text-sm text-neutral-400 mt-1";
  mainContentSectionWrapper = A.class_ "flex w-lg justify-between space-x-4 mt-8";
  mainContentSectionTitle = A.class_ "font-swear italic text-neutral-100 text-xl mb-4";
}]

let semiCircleGradient = [%bs.obj {
  backgroundPurple = A.style "background: radial-gradient(circle at bottom center, rgb(192 132 252 / 25%) 0%, rgb(192 132 252 / 8%) 20%, rgb(192 132 252 / 3%) 30%, rgb(23,23,23) 50%, rgb(23,23,23) 100%);";
  background = A.style "background: radial-gradient(circle at bottom center, rgb(255 107 0 / 25%) 0%,  rgb(255 107 0 / 8%) 20%, rgb(255 107 0 / 3%) 30%, rgb(23,23,23) 50%, rgb(23,23,23) 100%)";
}]

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
      H.a [ styles##menuItemLink ; A.href {j|/$link|j} ] [
        title
      ]
    ]
  )

let introduction = 
  H.div [ A.class_ "text-neutral-100" ] [
    H.h1 [ styles##headingTitle ] ["Fahmi Irsyad Khairi"]
  ; H.p [ styles##headingDesc ] [
      {j| Web developer / full-time frontend developer based in Indonesia, <strong>passionate</strong>
      about <strong>experiment</strong> with things, build <strong>solid</strong> <strong>performant</strong> creative software.|j}
    ]
  ]

let mainWrapper sidebar main = 
  H.section [ styles##mainWrapper; styles##mainWrapperRaw ] [
    sidebar
  ; main
  ]

let sidebarContent sources = 
  H.aside [] [
    H.div [ A.class_ "mb-6"; ] [
      Logo.logo 70 "#f5f5f5"
    ]
  ; H.h1 [ styles##sidebarTitle ] [
      {js|Fa—h.|js}
    ]
  ; H.ul [ styles##sidebarMenu ] (
      listMenu (listMenuData sources)
    )
  ]

let mainContent sources =
  let blog = sources.blog |> Array.to_list in
  let projects = sources.projects |> Array.to_list in
  let processArticle source =
    source |> List.map (fun meta ->
      let caption =
        match meta.data.caption with
        | Some(data) -> data
        | None -> ""
      in
      H.li [ A.class_ "text-neutral-200 mb-4"] [
        H.a [ A.class_ "group"; A.href meta.url ] [
          H.h3 [ styles##mainContentItemTitle ] [ meta.data.title ]
        ; H.p [ styles##mainContentItemCaption ] [ caption ]
        ]
      ]
    )
  in
  H.div [ A.class_ "px-28" ] [
    introduction
  ; H.div [ styles##mainContentSectionWrapper ] [
      H.div [ A.class_ "w-64" ] [
        H.h2 [ styles##mainContentSectionTitle ] [ "Recent article" ]
      ; H.ul [] (processArticle blog)
      ]
    ; H.div [ A.class_ "w-64" ] [
        H.h3 [ styles##mainContentSectionTitle ] [ "Recent project" ]
      ; H.ul [] (processArticle projects)
      ]
    ]
  ]

let main sources =
  H.html [ A.lang "en" ] [
    Seo.head ~children: "" ()
  ; H.body [ styles##body ] [
      H.main [ A.class_ "min-h-screen relative"; semiCircleGradient##background ] [
        mainWrapper (sidebarContent sources) (mainContent sources)
      ; Footer.elem ~source: "https://github.com/fahmiirsyadk/site" ~fixed: true
      ]
    ]
  ]