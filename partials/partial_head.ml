module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let metaContent (ct: string) (nm:string) =
  H.meta [
    (P.content ct);
    (P.name nm);
  ] []

let head ~title:(title: string) =
  H.head [] [
    (H.meta [ P.charset "utf-8"] []);
    metaContent "width=device-width,initial-scale=1" "viewport";
    metaContent "#000" "theme-color";
    (H.title [] (H.text title));
    metaContent "fahmiirsyadk -- Web developer based on Banyuwangi, Indonesia." "description";
    H.style [] (H.text (E.inject "assets/css/style.css"));
  ]
