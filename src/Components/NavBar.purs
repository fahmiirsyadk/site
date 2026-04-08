module Components.NavBar where

import Prelude

import Routes (printRoutePath)
import Types (Route(..))
import Luna.Html as H
import Luna.Html (Html)

navBar :: forall i. Route -> Html i
navBar current =
  H.nav
    [ H.classes [ "navbar", "flex", "items-center", "justify-between", "p-4" ] ]
    [ H.div [ H.classes [ "nav-brand" ] ]
        [ navLink Home "Home" current
        , navLink ArticlesIndex "Articles" current
        , navLink ProjectsIndex "Projects" current
        , navLink About "About" current
        ]
    ]

navLink :: forall i. Route -> String -> Route -> Html i
navLink route label current =
  H.a
    [ H.href (printRoutePath route)
    , H.classes $ [ "nav-link", "px-3", "py-2" ] <> if current == route then [ "text-white", "font-bold" ] else [ "text-zinc-400", "hover:text-white" ]
    ]
    [ H.text label ]