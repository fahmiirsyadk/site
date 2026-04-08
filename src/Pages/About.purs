module Pages.About where

import Luna.Html as H
import Luna.Html (Html)

view :: forall i. Html i
view =
  H.div [ H.classes [ "space-y-5" ] ]
    [ H.h1 [ H.classes [ "text-[12px]", "leading-[1.7]", "font-semibold", "text-[#171717]" ] ] [ H.text "About" ]
    , H.p [ H.classes [ "text-[12px]", "leading-[1.7]", "text-neutral-600" ] ]
        [ H.text "This is a static site generated with Luna and PureScript." ]
    ]