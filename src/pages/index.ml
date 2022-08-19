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

(* let logoSection w h =
  (* let w = 125 - in *)
   H.div [] [
    {j|
    <svg width="$w" height="$h" viewBox="0 0 125 57" fill="white" xmlns="http://www.w3.org/2000/svg">
      <path d="M0.896283 29.1184C0.322916 29.6824 0 30.4529 0 31.2572V53.5C0 55.1569 1.34315 56.5 3 56.5H29.2406C30.0461 56.5 30.8179 56.176 31.382 55.601L44.8586 41.8653C46.74 39.9476 50 41.2798 50 43.9663V53.5C50 55.1569 51.3431 56.5 53 56.5H97.2406C98.0461 56.5 98.8179 56.176 99.382 55.601L123.641 30.8751C124.192 30.3142 124.5 29.5598 124.5 28.7741V3C124.5 1.34315 123.157 0 121.5 0H111.743C110.947 0 110.184 0.316071 109.621 0.87868L101.621 8.87868C99.7314 10.7686 96.5 9.43007 96.5 6.75736V3C96.5 1.34315 95.1569 0 93.5 0H81.7281C80.9411 0 80.1855 0.309303 79.6244 0.861221L61.6037 18.5865C59.7068 20.4523 56.5 19.1085 56.5 16.4477V3C56.5 1.34315 55.1569 0 53.5 0H31.7281C30.9411 0 30.1855 0.309303 29.6244 0.861222L0.896283 29.1184Z" fill="white" />
      </svg>
    |j}
  ]

let topNav =
  H.nav [ A.class_ "w-full flex justify-center" ] [
    H.div [] [
      logoSection 80 40
    ]
  ]

let sidebar =
  H.aside [ A.class_ "-mt-[6px] flex flex-nowrap flex-col gap-y-5 w-[40rem] md:w-[25rem] lg:w-[30rem] xl:w-[40rem] 2xl:w-[40rem]" ] [
    H.h1 [ A.class_ "text-5xl font-swear font-bold italic" ] [ "Fa-h" ]
  ; H.q [ A.class_ "text-sm font-medium text-neutral-500 italic max-w-sm leading-relaxed pb-10" ] [ "Personal journal as place for thoughts." ]
  ]


let sectionContents ~writings:(writings: metadata list) ~projects:(projects: metadata list) () =
  (* writings fetch *)
  let projectsContent =
    if projects |> List.length > 0 then [ "coming soon" ] else [ "coming soon" ] in
  let writingsContent =
    writings |> List.map (fun res ->
      let caption =
        match res.data.caption with
        | Some(data) -> data
        | None -> ""
      in
      H.li [ A.class_ "mb-4 leading-loose"] [
        H.a [ A.href res.url; A.class_ "group" ] [
          H.h3 [ A.class_ "font-semibold group-hover:underline group-hover:underline-offset-2 text-neutral-200" ] [ res.data.title ]
        ; H.p [ A.class_ "text-sm text-neutral-300" ] [ caption ]
        ]
      ]
    ) in
  (* projects fetch *)
  H.section [ A.class_ "pt-14 flex flex-row flex-wrap gap-x-10 flex-1" ] [
    H.div [ A.class_ "max-w-sm lg:flex-1" ] [
      H.h2 [ A.class_ "font-swear italic text-2xl text-neutral-100 font-bold tracking-wide antialiased" ] [ "Writings" ]
    ; H.article [] [
        H.ul [ A.class_ "mt-4"] writingsContent
      ]
    ]
  ; H.div [ A.class_ "max-w-sm lg:flex-1" ] [
      H.h2 [ A.class_ "font-swear italic text-2xl text-neutral-100 font-bold tracking-wide antialiased" ] [ "Works" ]
    ; H.article [] [
        H.ul [] projectsContent
      ]
    ]
  ]

let mainContent w p =
  H.section [ A.class_ "flex flex-col gap-y-5 flex-1 text-neutral-300" ] [
    H.p [ A.class_ "font-medium max-w-md leading-relaxed" ] [ "<strong>Fahmi</strong> is a front-end developer based in Banyuwangi, Indonesia. Through this site, he writes journals, portfolios, or showcases some of his experiments." ]
  ; H.p [ A.class_ "font-medium max-w-md leading-relaxed" ] [
      "Right now, he is learning react, a little bit of backend and design exploration. In addition, he is also interested in web3 & low-level programming."
    ]
  ; (sectionContents ~writings: w ~projects: p ())
  ] *)

let customCSS = 
  H.style [] [
    {|#terminal::-webkit-scrollbar { width: 0; }|}
  ]

let asciiToElem list =
  list |> List.map 
    (fun s -> 
      H.code [ A.class_ "block font-sans" ] [ s ])

let bannerASCII = 
  [
    ({|+-------------------------------------+|})
  ; ({||      _________________________      ||})
  ; ({||      \_____  ,__, ,__, ,_____/      ||})
  ; ({||       _____| |__| |__| |_____       ||})
  ; ({||       \____, ,_______, ,____/       ||})
  ; ({||            | |       | |            ||})
  ; ({||@           | |       | |           @||})
  ; ({||@@;;;       | |   *   | |       ;;;@@||})
  ; ({||@@@;;@;;@;;@| |,,.|.,,| |@;;@;;@;;@@@||})
  ; ({|+------------| |-------| |------------+|})
  ] |> asciiToElem

let swordASCII =
  [
    ({|        /                         |})
  ; ({j| */////{<>ΞΞΞΞΞΞΞΞΞΞΞ===========- |j})
  ; ({|        \                         |})
  ] |> asciiToElem


let tocSection = 
  H.section [ A.class_ "space-y-4"] [
    H.h2 [] [ {|[01] <b>Writing</b>........................................[ <a href='#' class="hover:text-orange-600">More</a> ]|} ]
  ; H.h2 [] [ {|[02] <b>Projects</b>.......................................[ <a href='#' class="hover:text-orange-600">More</a> ]|} ]
  ; H.h2 [] [ {|[03] <b>About</b>..........................................[ <a href='#' class="hover:text-orange-600">More</a> ]|} ]
  ; H.p [] ["I'm <b class='text-orange-600'>fahmi</b>, a front-end developer who <i>kinda</i> like experiment with things. Through this site, I write journals, portfolios, or showcases some of my experiments."]
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
    (* H.div [ A.class_ "rotate-90" ] swordASCII *)
    H.p [] [ "Load system kernel v1.0.1..." ]
  ; H.p [] [ "Success kernel v1.0.1..." ]
  ; H.p [] [ "Processing modules 1/85" ]
  ; H.p [] [ "Processing modules 83/85" ]
  ; H.p [] [ "Modules loaded successfully" ]
  ; H.p [] [ "Mounting OS..." ]
  ; H.p [] [ "." ]
  ; H.p [] [ "." ]
  ; H.pre [] swordASCII
  ; H.p [] [ "." ]
  ; H.p [ A.class_ "text-orange-600" ] [ "ChaOS v1.0" ]
  ; H.p [] [ "Welcome to the system!" ]
  ; H.div [ A.id "input-panel"; A.class_ "flex" ] [
      H.p [] [ "~# "]
    ; H.input [ A.id "input-cmd"; A.type_ "text"; A.class_ "bg-transparent outline-none pl-2 w-full"] []
    ]
  ]

let main sources =
  (* let writings = sources.writings |> Array.to_list in *)
  H.html [] [
    Seo.head ~children: [ customCSS ] ()
  ; H.body [ A.class_"text-md bg-neutral-100" ] [
      H.main [ A.class_ "flex items-start justify-center min-h-screen" ] [
        H.div [ A.id "loading-state" ] []
      ; H.section [ A.class_ "p-10 max-w-2xl w-full" ] [
        H.div [ A.class_ "flex w-full justify-center items-center"] [
          logoSection 60 30
        ]
        ; H.pre [ A.class_ "text-sm text-center my-4"; ] bannerASCII
        (* ; H.pre [ A.class_ "text-sm"; ] swordASCII *)
        ; H.p [ A.class_ "text-sm italic text-center" ] ["Personal journal as place for thoughts."]
        ; H.p [ A.class_ "text-sm text-center my-4"] [ "~~*~~"]
        ; tocSection
        ]
      ]
      ; logs
      ; btnLogs
      ; footer
      ; H.script [ A.src "/assets/js/cmd.js" ] []
    ]
  ]