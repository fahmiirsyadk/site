module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra

let metaContent nm ct =
  H.meta [
    P.content ct;
    P.name nm;
  ] []

let icon = H.link [
  P.href "/assets/images/favicon.ico";
  P.rel "shortcut icon";
  P.type_ "image/x-icon";
] []

let preloadFont fontName = H.link [
  P.rel "preload";
  P.href ("/assets/fonts/" ^ fontName);
  P.as_ "font";
  P.crossorigin "";
] []

let head ~title:(title: string) =
  H.head [] [
    H.meta [ P.charset "utf-8"] [];
    H.title [] (H.text title);
    metaContent Viewport "width=device-width,initial-scale=1" ;
    metaContent ThemeColor "#000";
    metaContent Description "fahmiirsyadk -- a Web developer based on Banyuwangi, Indonesia.";
    icon;
    preloadFont "Inter-var-latin.woff2";
    preloadFont "EditorialNew-Regular.otf";
    preloadFont "EditorialNew-Italic.otf";
    preloadFont "EditorialNew-Ultrabold.otf";
    H.link [
      P.rel "manifest";
      P.href "/site.webmanifest";
    ] [];
    H.style [] (H.text (E.inject "src/assets/css/style.css"));
  ]