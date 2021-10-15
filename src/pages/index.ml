module H = Dust.Html.Elements
module A = Dust.Html.Attributes

let stylesGradient = {|
  z-index: -1;
  filter: blur(54px);
|}

let cigraFont = {|
@font-face {
  font-family: 'Cigra';
  src: url('/assets/fonts/Cigra.eot'); /* IE9 Compat Modes */
  src: url('/assets/fonts/Cigra.eot?#iefix') format('embedded-opentype'), /* IE6-IE8 */
       url('/assets/fonts/Cigra.woff') format('woff'), /* Modern Browsers */
       url('/assets/fonts/Cigra.ttf') format('truetype'); /* Safari, Android, iOS */
           font-style: normal;
  font-weight: normal;
  text-rendering: optimizeLegibility;
}
|}

let bgColor = "#F0E7DB"

let leftPanel =
  H.div [ A.class_ "flex-1 h-full rounded-lg oveflow-hidden"] [
    H.article [ A.class_ "bg-white shadow-sm"] [
      H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
      ; H.h1 [] (H.text "ini content 1")
    ]
  ]

let rightPanel =
  H.aside [ A.class_ "flex-none w-96 h-full overflow-auto rounded-lg"] [
    H.div [ A.style "height: calc(100vh - 2em);"; A.class_ "fixed top-0 shadow-sm w-96 my-4 rounded-lg"] [
      H.h1 [ A.class_ "text-center font-semibold tracking-wide text-gray-800 text-4xl mt-48"; A.style "font-family: Cigra;"] (H.text "fahmiirsyadk")
    ]
  ]

let container children = 
  H.section [
    A.class_ "p-4 flex h-screen space-x-4"
  ] children

let navbar () =
  H.header [] [
    H.nav [] []
  ]

let main () =
  H.html
    [] [ 
      Seo.head ~children: (H.style [] (H.text cigraFont)) ()
      ; H.body [ A.style {j|background-color: $bgColor; background-image: url(/assets/images/noise.svg); |j} ] [
        H.div [ A.style stylesGradient; A.class_ "-bottom-24 bg-yellow-400 fixed w-full h-4/6 rounded-t-full opacity-70 "] []
        ; navbar ()  
        ; container [rightPanel; leftPanel]
      ]
    ]
