module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let metaContent (ct: string) (nm:string) =
  H.meta [
    P.content ct;
    P.name nm;
  ] []

let icon = H.link [
  P.href "/assets/images/favicon.ico";
  P.rel "shortcut icon";
  P.type_ "image/x-icon";
] []

let head ~title:(title: string) =
  H.head [] [
    H.meta [ P.charset "utf-8"] [];
    H.title [] (H.text title);
    metaContent "width=device-width,initial-scale=1" "viewport";
    metaContent "#000" "theme-color";
    metaContent "fahmiirsyadk -- a Web developer based on Banyuwangi, Indonesia." "description";
    icon;
    H.style [] (H.text (E.inject "assets/css/style.css"));
  ]
