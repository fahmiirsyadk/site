module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

let logoSection w h =
  (* let w = 125 - in *)
   H.div [] [
    {j|
    <svg width="$w" height="$h" viewBox="0 0 125 57" fill="bg-neutral-900" xmlns="http://www.w3.org/2000/svg">
      <path d="M0.896283 29.1184C0.322916 29.6824 0 30.4529 0 31.2572V53.5C0 55.1569 1.34315 56.5 3 56.5H29.2406C30.0461 56.5 30.8179 56.176 31.382 55.601L44.8586 41.8653C46.74 39.9476 50 41.2798 50 43.9663V53.5C50 55.1569 51.3431 56.5 53 56.5H97.2406C98.0461 56.5 98.8179 56.176 99.382 55.601L123.641 30.8751C124.192 30.3142 124.5 29.5598 124.5 28.7741V3C124.5 1.34315 123.157 0 121.5 0H111.743C110.947 0 110.184 0.316071 109.621 0.87868L101.621 8.87868C99.7314 10.7686 96.5 9.43007 96.5 6.75736V3C96.5 1.34315 95.1569 0 93.5 0H81.7281C80.9411 0 80.1855 0.309303 79.6244 0.861221L61.6037 18.5865C59.7068 20.4523 56.5 19.1085 56.5 16.4477V3C56.5 1.34315 55.1569 0 53.5 0H31.7281C30.9411 0 30.1855 0.309303 29.6244 0.861222L0.896283 29.1184Z" fill="bg-neutral-900"/>
      </svg>
    |j}
  ]


let navigation =
  let items = List.map 
    (fun a -> 
      H.li [ A.class_ "rounded-lg px-4 text-neutral-700 ease-in-out duration-100 py-1.5 cursor-pointer border border-transparent bg-white hover:text-black hover:shadow-sm hover:shadow-neutral-100 hover:border-neutral-300 hover:translate-y-1 antialiased" ] [a]
    ) [ "writings"; "projects"; "about" ] in
  H.nav [ A.class_ "h-14 text-sm flex items-center" ] [
    logoSection 80 40
  ; H.ul [ A.class_ "ml-4 flex space-x-2 items-center font-medium" ] items
  ]

let wrapperBg child = 
  H.main [ A.class_ "w-full pt-0 p-4"; A.style "height: calc(100vh - 3.5rem);" ] [
    navigation
  ; H.div [ A.class_ "bg-white border border-neutral-300 w-full min-h-full rounded-md p-8" ] [
      child
    ; H.footer [ A.class_ "mt-4 space-x-2" ] [
        H.a [ A.href "https://www.github.com/fahmiirsyadk/site/"; A.rel_a `Noopener; A.class_ "underline font-semibold text-sm underline-offset-2 text-neutral-800 hover:text-orange-500 italic" ] [ "Source code" ]
      ; H.span [ A.class_ "text-neutral-300" ] [ "/" ]
      ; H.a [ A.href "https://www.twitter.com/fahmiirsyadk/"; A.rel_a `Noopener; A.class_ "underline font-semibold text-sm underline-offset-2 text-neutral-700 hover:text-sky-500 italic" ] [ "Twitter" ]
      ; H.span [ A.class_ "text-neutral-300" ] [ "/" ]
      ; H.a [ A.href "https://www.linkedin.com/in/fahmi-irsyad-khairi-3b2aa414a/"; A.rel_a `Noopener; A.class_ "underline font-semibold text-sm underline-offset-2 text-neutral-700 italic hover:text-blue-800" ] [ "Linkedin" ]
      ]
    ]
  ]

let sectionTitle =
  H.section [ A.class_ "flex flex-nowrap flex-col gap-y-5 w-[40rem] antialiased" ] [
    H.h1 [ A.class_ "text-5xl font-swear font-bold italic" ] [ "Fa-h" ]
  ; H.q [ A.class_ "text-sm font-medium text-neutral-600 italic max-w-sm leading-relaxed" ] [ "Personal journal as place for thoughts." ]
  ; H.p [ A.class_ "text-sm font-medium text-neutral-700 max-w-sm leading-relaxed" ] [ "<strong>Fahmi</strong> is a front-end developer based in Banyuwangi, Indonesia. Through this site, he writes journals, portfolios, or shows some of his experiments." ]
  ; H.p [ A.class_ "text-sm font-medium text-neutral-700 max-w-sm leading-relaxed" ] [
      "Right now, he learn react, a little bit of backend and design exploration. Beside that, he also interested about web3 & low-level programming. "
    ]
  ; H.hr [ A.class_ "max-w-sm" ] []
  ]

let sectionContents =
  H.section [ A.class_ "flex flex-col gap-y-10 flex-1" ] [
    H.div [ A.class_ "pt-14" ] [
      H.h2 [ A.class_ "font-swear italic text-xl text-neutral-900 font-bold tracking-wide antialiased" ] [ "Writings" ]
    ; H.article [] [
        H.ul [] [
          H.li [] [ "Contoh" ]
        ]
      ]
    ]
  ; H.div [] [
      H.h2 [ A.class_ "font-swear italic text-xl text-neutral-900 font-bold tracking-wide antialiased" ] [ "Works" ]
    ; H.article [] [
        H.ul [] [
          H.li [] [ "Contoh" ]
        ]
      ]
    ]
  ]

let patternBG =
  H.style [] [
    {|
      body {
        background-color: #EFEFEF;
        background-image:  radial-gradient(#969696 1.1px, transparent 1.1px), radial-gradient(#969696 1.1px, #EFEFEF 1.1px);
        background-size: 44px 44px;
        background-position: 0 0,22px 22px;
      }
    |}
  ]

let main () =
  H.html [] [
    Seo.head ~children: [ patternBG ] ()
  ; H.body [ A.class_ "bg-[#EFEFEF]" ] [
      wrapperBg (H.div [ A.class_ "flex flex-wrap flex-row"] [
        sectionTitle
      ; sectionContents
      ])
    ]
  ]

(* let styles = [%bs.obj {
  customStyles = H.style [] [
    {|
      body {
        scrollbar-width: none;
      }
      body::-webkit-scrollbar {
        display: none;
      }
    |}
  ]
; mainSection = A.class_ {j|min-h-screen|j}
; introSection = A.class_ "py-32 px-[14%]"
}]

let locomotiveJs =
  H.script [ A.src "/assets/js/locomotive.min.js"; ] []

let filter = {j|
  <svg xmlns="http://www.w3.org/2000/svg" version="1.1">
  <defs>
    <filter id="goo">
      <feGaussianBlur in="SourceGraphic" stdDeviation="10" result="blur" />
      <feColorMatrix in="blur" mode="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 18 -7" result="goo" />
      <feComposite in="SourceGraphic" in2="goo" operator="atop"/>
    </filter>
  </defs>
  </svg>
|j}

let patternBG = A.style {|
  background-image: url(/assets/images/cross-pattern.svg), url(/assets/images/cross-pattern.svg);
  background-size: calc(20 * 10px) calc(20 * 10px);
  background-position: 0 0,calc(10 * 10px) calc(10 * 10px);
|}

let logoSection = 
  H.div [ A.class_ "mb-4" ] [
    {j|
    <svg width="125" height="57" viewBox="0 0 125 57" fill="bg-neutral-900" xmlns="http://www.w3.org/2000/svg">
      <path d="M0.896283 29.1184C0.322916 29.6824 0 30.4529 0 31.2572V53.5C0 55.1569 1.34315 56.5 3 56.5H29.2406C30.0461 56.5 30.8179 56.176 31.382 55.601L44.8586 41.8653C46.74 39.9476 50 41.2798 50 43.9663V53.5C50 55.1569 51.3431 56.5 53 56.5H97.2406C98.0461 56.5 98.8179 56.176 99.382 55.601L123.641 30.8751C124.192 30.3142 124.5 29.5598 124.5 28.7741V3C124.5 1.34315 123.157 0 121.5 0H111.743C110.947 0 110.184 0.316071 109.621 0.87868L101.621 8.87868C99.7314 10.7686 96.5 9.43007 96.5 6.75736V3C96.5 1.34315 95.1569 0 93.5 0H81.7281C80.9411 0 80.1855 0.309303 79.6244 0.861221L61.6037 18.5865C59.7068 20.4523 56.5 19.1085 56.5 16.4477V3C56.5 1.34315 55.1569 0 53.5 0H31.7281C30.9411 0 30.1855 0.309303 29.6244 0.861222L0.896283 29.1184Z" fill="bg-neutral-900"/>
    </svg>
    |j}
  ]

  

let logoSectionBG = 
  H.div [] [
    {j|
    <svg preserveAspectRatio="xMidYMid meet" width="100%" viewBox="0 0 125 57" fill="white" xmlns="http://www.w3.org/2000/svg">
      <path d="M0.896283 29.1184C0.322916 29.6824 0 30.4529 0 31.2572V53.5C0 55.1569 1.34315 56.5 3 56.5H29.2406C30.0461 56.5 30.8179 56.176 31.382 55.601L44.8586 41.8653C46.74 39.9476 50 41.2798 50 43.9663V53.5C50 55.1569 51.3431 56.5 53 56.5H97.2406C98.0461 56.5 98.8179 56.176 99.382 55.601L123.641 30.8751C124.192 30.3142 124.5 29.5598 124.5 28.7741V3C124.5 1.34315 123.157 0 121.5 0H111.743C110.947 0 110.184 0.316071 109.621 0.87868L101.621 8.87868C99.7314 10.7686 96.5 9.43007 96.5 6.75736V3C96.5 1.34315 95.1569 0 93.5 0H81.7281C80.9411 0 80.1855 0.309303 79.6244 0.861221L61.6037 18.5865C59.7068 20.4523 56.5 19.1085 56.5 16.4477V3C56.5 1.34315 55.1569 0 53.5 0H31.7281C30.9411 0 30.1855 0.309303 29.6244 0.861222L0.896283 29.1184Z" fill="white"/>
    </svg>
    |j}
  ]

let descriptionSection =
  let italicStyle = A.class_ "font-swear text-orange-600" in
  let exp = H.i [ italicStyle ] [ "Experiment" ] in
  let cr = H.i [ italicStyle ] [ "creative" ] in
  H.div [ A.class_ "max-w-lg" ] [
    H.h1 [ A.class_ "text-4xl font-bold leading-snug text-neutral-900" ] [
      {j|$exp with things, build solid performant $cr software.|j}
    ]
  ; H.p [ A.class_ "mt-20 mb-8 text-base text-neutral-700 font-medium leading-loose" ] [
      "<strong>Fahmi</strong> is a front-end developer based in Banyuwangi, Indonesia. Through this site, he writes journals, portfolios, or shows some of his experiments."
    ]
  ; H.i [ A.class_ "font-swear text-xl font-bold" ] [ {js|⁜ Current state|js} ]
  ; H.p [ A.class_ "mt-4 text-base text-neutral-700 font-medium leading-loose" ] [
      "Right now, learning & building react stuff. Beside that i also learn about web3, a little bit of backend and design exploration. I listen to playlists a, b, c to increase my productivity."
    ] 
  ]

let introSection children = 
  H.div [ styles##introSection ] children

let rulerNavigator =
  let sm = H.div [ A.class_ "w-5 h-1 bg-zinc-200 rounded-md" ] [] in
  let lg = H.div [ A.class_ "w-9 h-1 bg-zinc-300 rounded-md" ] [] in
  let rec ruler total counter elem isFive =
    (* TODO:
        elements iterators with rule every 5th element is lg otherwise sm
    *)
    let isFiveBool = isFive + 1 == 5 in
    let elemCount = if isFiveBool then lg else sm in
    if counter > total then []
    else elem :: ruler 15 (counter + 1) elemCount (if isFiveBool then 0 else (isFive + 1)) 
  in
  H.nav [ A.class_ "fixed flex flex-col items-end space-y-2 top-1/3 right-8"] 
  (ruler 15 0 lg 0)

let main () = 
  H.html [] [
    Seo.head ~children: [
      styles##customStyles
    ; locomotiveJs
    ] ()
  ; H.body [] [
      (* container *)
      H.main [ A.class_ " min-h-screen bg-white" ] [
        rulerNavigator
      ; H.section [ A.class_ "h-screen w-full bg-black px-10 py-6" ] [
          logoSectionBG
        ]
      ; H.section [ styles##mainSection ] [
          introSection [
            H.div [ A.class_ "flex"] [
              logoSection
              ]
          ; descriptionSection
          ]
        ; filter
        ]
      ]
    ; jsScript
    ]
  ] *)