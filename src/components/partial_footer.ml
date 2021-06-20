
module H = Mana.HTML
module P = Mana.Property
module E = Mana.Extra
let footer = H.footer [] [
    H.a [ P.href "https://github.com/fahmiirsyadk/site" ] [
        H.span [] (H.text "View source on Github");
    ];
    H.div [] [];
    H.p [ P.style "font-weight: bold;" ] (H.text {js|Made with <3 from banyuwangi.|js});
]
