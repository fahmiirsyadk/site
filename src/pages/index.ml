module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Extras


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
  { writings : metadata array
  ; projects: metadata array
  }

let logoSection w h =
  H.div [] [
    {j|
    <svg width="$w" height="$h" viewBox="0 0 125 57" fill="black" xmlns="http://www.w3.org/2000/svg">
      <path d="M0.896283 29.1184C0.322916 29.6824 0 30.4529 0 31.2572V53.5C0 55.1569 1.34315 56.5 3 56.5H29.2406C30.0461 56.5 30.8179 56.176 31.382 55.601L44.8586 41.8653C46.74 39.9476 50 41.2798 50 43.9663V53.5C50 55.1569 51.3431 56.5 53 56.5H97.2406C98.0461 56.5 98.8179 56.176 99.382 55.601L123.641 30.8751C124.192 30.3142 124.5 29.5598 124.5 28.7741V3C124.5 1.34315 123.157 0 121.5 0H111.743C110.947 0 110.184 0.316071 109.621 0.87868L101.621 8.87868C99.7314 10.7686 96.5 9.43007 96.5 6.75736V3C96.5 1.34315 95.1569 0 93.5 0H81.7281C80.9411 0 80.1855 0.309303 79.6244 0.861221L61.6037 18.5865C59.7068 20.4523 56.5 19.1085 56.5 16.4477V3C56.5 1.34315 55.1569 0 53.5 0H31.7281C30.9411 0 30.1855 0.309303 29.6244 0.861222L0.896283 29.1184Z" fill="black" />
      </svg>
    |j}
  ]

let customCSS = 
  H.style [] [
    {|#terminal::-webkit-scrollbar { width: 0; }|}
  ]

let smallIntroduction =
  H.h1 [] ["I'm <strong>fahmi</strong>, a front-end developer who <i>kinda</i> like experiment with things. Through this site, I write journals, portfolios, or showcases some of my experiments."]  
  
let tocSection writings =
  let articleItem res =
    let title = res.data.title in
    let link = res.url in
    H.a [ A.href {j|$link|j}; A.class_ "flex justify-between group items-center" ] [
      H.div [ A.class_ "flex space-x-2 font-bold sm:-ml-2"] [
        H.span [ A.class_ "sm:hidden sm:invisible" ] [ {j|↪|j} ]
        ; H.h3 [ A.class_ "flex-1 underline decoration-wavy decoration-neutral-400 underline-offset-2 group-hover:decoration-orange-600" ] [ {j|$title|j} ]
        ; H.span [ A.class_ "text-transparent group-hover:text-orange-600" ] [{j|⁕|j} ] 
      ]
      ; H.span [ A.class_ "flex-none italic text-neutral-600 text-xs" ] [ "--- Sat, Aug 20 2022" ]
    ]
  in
  let menus =
    [
      ("01", "About", smallIntroduction)
    ; ("02", "Writings", (writings |> Utils.combineElement (fun res -> articleItem res)))
    ; ("03", "Projects", "")
    ]
  in
  let menuElem num title menu =
    H.article [] [
      H.h2 [ A.class_ "relative flex justify-between w-full before:absolute before:bottom-[0.4rem] before:w-full before:leading-[0px] before:border-black before:border-b-2 before:border-dotted text-neutral" ] [
        H.span [ A.class_ "bg-neutral-100 pr-1 relative z-10" ] [
          {j|[$num] |j} ^ H.b [ A.class_ "italic text-neutral-700" ] [ title ]
        ]
      ; H.span [ A.class_ "bg-neutral-100 space-x-2 relative z-10 flex items-center" ] [ 
        H.span [] [ "[" ]
        ; H.a [ A.href "#"; A.class_ "hover:text-orange-600" ] [ "More" ]
        ; H.span [] [ "]" ]
        ]
      ]
    ; H.div [ A.class_ "my-4" ] [ menu ]
    ]
  in
  H.section [] [
    ( menus |> Utils.combineElement3 (fun a b c -> menuElem a b c))
  ]

let footer =
  let renderYear = 
    Js.Date.now () 
    |> Js.Date.fromFloat 
    |> Js.Date.getFullYear 
    |> Js.Float.toString
  in
  let dustver = Dust.Extras.getVersion() in
  let renderTime = Js.Date.now() |> Js.Date.fromFloat |> Js.Date.toUTCString in
  let flower1 pos =
    H.pre [ A.class_ {j|text-sm absolute bottom-0 $pos|j}] [
      H.code [ A.class_ "block font-sans text-orange-600 font-bold" ] [ "***" ]
    ; H.code [ A.class_ "block font-sans text-orange-600 font-bold" ] [ "***" ]
    ; H.code [ A.class_ "block font-sans" ] [ " |" ]
    ; H.code [ A.class_ "block font-sans" ] [ " |" ]
    ] in
  let flower2 pos =
    H.pre [ A.class_ {j|text-sm absolute bottom-0 $pos|j} ] [
      H.code [ A.class_ "block font-sans" ] [ " " ]
    ; H.code [ A.class_ "block font-sans" ] [ " " ]
    ; H.code [ A.class_ "block font-sans text-orange-600 font-bold" ] [ {|@|} ]
    ; H.code [ A.class_ "block font-sans" ] [ {|||} ]
    ] in
  H.footer [ A.class_ "relative h-64 bg-neutral-100" ] [
    H.div [ A.class_ "text-xs absolute z-0 bottom-2 text-neutral-600 w-full text-center" ] [
      {j|fa-h $renderYear | Dust $dustver at $renderTime |j}
    ]
  ;  flower2 "right-14"
  ; flower1 "right-56"
  ; flower2 "right-64"
  ; flower1 "left-14"
  ; flower2 "right-32"
  ; flower1 "right-20"
  ; flower2 "left-56"
  ]

let btnLogs =
  let text = H.span [ A.class_ "group-hover:text-orange-600 font-bold" ] [ "Show/Hide terminal" ] in
  H.div [ A.id "terminal-btn"; A.class_ "fixed z-10 text-neutral-800 text-sm bottom-0 left-0 p-4 cursor-pointer group" ] [ {j|[ $text ]|j} ]

let logs =
  H.div [ A.id "terminal"; A.class_ "w-full z-10 max-w-fit fixed space-y-2 top-0 bottom-0 left-0 overflow-y-scroll  p-4 text-neutral-500 overflow-y text-xs" ] [
    H.p [] [ "Load system kernel v1.0.1..." ]
  ; H.p [] [ "Success kernel v1.0.1..." ]
  ; H.p [] [ "Processing modules 1/85" ]
  ; H.p [] [ "Processing modules 83/85" ]
  ; H.p [] [ "Modules loaded successfully" ]
  ; H.p [] [ "Mounting OS..." ]
  ; H.p [] [ "." ]
  ; H.p [] [ "." ]
  ; H.pre [] Ascii.swordASCII
  ; H.p [] [ "." ]
  ; H.p [ A.class_ "text-orange-600" ] [ "ChaOS v1.0" ]
  ; H.p [] [ "Welcome to the system!" ]
  ; H.div [ A.id "input-panel"; A.class_ "flex" ] [
      H.p [] [ "~# "]
    ; H.input [ A.id "input-cmd"; A.type_ "text"; A.class_ "bg-transparent outline-none pl-2 w-full"] []
    ]
  ]

let main sources =
  let writings = sources.writings |> Array.to_list in
  (* let projects = sources.projects |> Array.to_list in *)
  H.html [ A.lang "id" ] [
    Seo.head ~children: [ customCSS ] ()
  ; H.body [ A.class_"bg-neutral-100" ] [
      H.main [ A.class_ "flex items-start justify-center min-h-screen" ] [
        H.div [ A.id "loading-state" ] []
      ; H.section [ A.class_ "p-10 max-w-2xl w-full" ] [
        H.div [ A.class_ "flex w-full justify-center items-center"] [
          logoSection 60 30
        ]
        ; H.div [ A.class_ "relative my-4 oveflow-hidden"] [
            H.div [ A.class_ "w-full h-[200px] sm:h-[160px] flex justify-center relative overflow-hidden cursor-pointer group" ] [
              H.pre [ A.class_ "text-sm text-center absolute select-none z-10 sm:text-xs"; ] Ascii.borderASCII
            ; H.pre [ A.class_ "text-sm text-center subpixel-antialiased select-none absolute font-bold translate ease-in-out z-0 duration-[1.2s] group-hover:scale-150 group-hover:translate-y-[-50px] sm:text-xs"; ] Ascii.banner1ASCII
            ; H.pre [ A.class_ "text-sm text-center subpixel-antialiased select-none absolute font-bold translate ease-in-out z-0 duration-1000 group-hover:scale-150 group-hover:opacity-0 sm:text-xs"; ] Ascii.banner3ASCII
            ; H.pre [ A.class_ "text-sm text-center subpixel-antialiased translate ease-in-out z-0 duration-1000 group-hover:scale-[10.0] group-hover:-translate-y-24 select-none absolute font-bold sm:text-xs"; ] Ascii.banner2ASCII
            ]
          ]
        ; H.h4 [ A.class_ "text-sm italic text-center" ] ["Personal journal as place for thoughts."]
        ; H.h4 [ A.class_ "text-sm text-center my-4"] [ "~~*~~"]
        ; tocSection writings
        ]
      ]
      (* ; logs *)
      (* ; btnLogs *)
      ; footer
      (* ; H.script [ A.src "/assets/js/cmd.js" ] [] *)
    ]
  ]
