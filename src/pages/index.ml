module H = Dust.Html.Elements
module A = Dust.Html.Attributes
module E = Dust.Html.Extra

(* let main _ =
  (* let blog = posts.blog |> Array.to_list in *)
  (* let projects = posts.projects |> Array.to_list in *)
  H.html [] [
    Seo.head ~children:"" ()
  ; H.body [
    A.class_ "bg-black"
  ] [
      (* H.main [ A.class_ "max-w-5xl mx-auto min-h-screen"] [
        header
      ; H.section [ A.class_ "my-24 px-24 sm:px-24 md:px-56 lg:px-56 space-x-12 flex justify-between"] 
          (H.text ((sections "Articles" blog) ^ (sections "Projects" projects) ^ (sections "Notes" [])))
      ] *)
    Footer.elem
    ]
  ] *)

let surrealScript = 
  H.script [ A.type_ "module" ] [ E.inject "js/surreal.js" ]

let wrapper = 
    H.section [] [

    ]
  (* H.section [ A.style templateColomn; A.class_ "grid place-content-center grid-rows-3 gap-x-4 place-items-stretch my-14 w-11/12" ] [
    H.div [ A.style mainSection; A.class_ "text-center" ] [
      H.h1 [ A.class_ "text-white font-swear italic text-5xl" ] (H.text (PageIndex.title ^ {js| ✦ |js}))
    ; H.p [ A.class_ "text-zinc-500 max-w-5x mt-4" ] [
        "Crafting the star, thou can still read my writings on "
      ; H.strong [ A.class_ "text-red-500" ] [ 
          "/blog" 
        ]
      ]
    ]
  ] *)

let main () =
  H.html [] [
    Seo.head ~children: "" ()
  ; H.body [ A.class_ "bg-black"] [
      H.main [ A.class_ "min-h-screen relative flex justify-center"] [
        wrapper
      (* ;  {|
        <video id="video" loop crossOrigin="anonymous" playsinline style="display:none">
          <source src="assets/images/okay.mp4" type='video/mp4; codecs="avc1.42E01E, mp4a.40.2"'>
        </video>
      |} *)
        ]
      ; Footer.elem
      ; H.canvas [ A.id "canvasme"; ] []
      (* ; surrealScript *)
    ]
  ]