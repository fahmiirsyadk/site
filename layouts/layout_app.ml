module H = Mana.HTML
module P = Mana.Property

let footer = Partial_footer.footer

let layout head section =
    H.html [] [
        ( head );
        ( H.body [] [
            ( section );
            ( footer );
        ])
    ]
