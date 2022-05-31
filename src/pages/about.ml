module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let styles = [%bs.obj {
  header = A.class_ "w-full select-none h-20 fixed top-0 text-neutral-400 flex items-center justify-center";
  headerRaw = A.style "background: linear-gradient(0deg, rgba(0,0,0,0) 0%, rgba(23,23,23,0.8) 82%, rgba(23,23,23,1) 100%);";
  nav = A.class_ "flex items-center content-center";
  navLink = A.class_ "font-medium hover:text-neutral-50 cursor-pointer";
  navLinkSelected = A.class_ "font-medium hover:text-neutral-50 cursor-pointer";
}]

let main () =
  H.html [ A.lang "en" ] [
    Seo.head ~children: "" ()
    ; H.body [ A.class_ "bg-neutral-900"] [
        H.header [ styles##header; styles##headerRaw ] [
            H.nav [ styles##nav ] [
              H.div [ A.class_ "space-x-6" ] [
                H.a [ A.href "/blog"; styles##navLink ] [ "Blog" ]
              ; H.a [ A.href "/projects"; styles##navLink ] [ "Projects" ]
              ]
            ; H.div [ A.class_ "mx-6 cursor-pointer" ] [
                H.a [ A.href "/" ] [
                  Logo.logoRatio 30 "#f5f5f5"
                ]
              ]
            ; H.div [ A.class_ "space-x-6" ] [
                H.a [ A.href "/about"; styles##navLink ] [ "About" ]
              ; H.a [ A.href "/resume"; styles##navLinkSelected ] [ "Resume" ]
              ]
            ]
        ]
      ; H.main [] [
        H.h1 [] [ "About ME" ]
      ]
    ]
  ]