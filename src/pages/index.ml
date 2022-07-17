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
  ]

let main sources =
  let writings = sources.writings |> Array.to_list in
  H.html [] [
    Seo.head ~children: [""] ()
  ; H.body [ A.class_" bg-[#101010] text-white" ] [
      H.div [ A.class_ "p-10" ] [
        topNav
      ; H.main [ A.class_ "pt-20 flex flex-wrap flex-row antialised" ] [
          sidebar
        ; mainContent writings []
        ]
      ]
    ]
  ]
