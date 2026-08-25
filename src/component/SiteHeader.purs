module Component.SiteHeader where

import Prelude

import App.Route as Route
import App.Site as Site
import Component.HollowMark as HollowMark
import Domain.Theme as Theme
import Component.Footer as Footer
import Foldkit.Html as HH
import Foldkit.Mount (MountAction)
import Foldkit.Html.Prop as HP

type Input message =
  { activeSection :: String
  , hollowInteraction :: String
  , labHoveredMessage :: message
  , labLeftMessage :: message
  , mount :: MountAction message
  , theme :: Theme.Theme
  , themeMessage :: message
  }

linkClass :: Boolean -> String
linkClass active =
  if active then
    "text-[#FF4B26] transition-colors dark:text-[#FF6B4A]"
  else
    "text-neutral-500 transition-colors hover:text-[#FF4B26] dark:text-neutral-400 dark:hover:text-[#FF6B4A]"

navigationLink :: forall message. String -> String -> String -> HH.Child message
navigationLink activeSection section label =
  HH.a
    [ HP.href (Route.sectionPath { section })
    , HP.ariaCurrent (if activeSection == section then "page" else "false")
    , HP.class_ (linkClass (activeSection == section))
    ] [ HH.text label ]

labLink :: forall message. Input message -> HH.Child message
labLink input =
  HH.a
    [ HP.href (Route.sectionPath { section: Site.labSection })
    , HP.ariaCurrent (if input.activeSection == Site.labSection then "page" else "false")
    , HP.dataAttribute "lab-link" "true"
    , HP.onMouseEnter { message: input.labHoveredMessage }
    , HP.onMouseLeave { message: input.labLeftMessage }
    , HP.class_ (linkClass (input.activeSection == Site.labSection))
    ] [ HH.text Site.labSection ]

sshLink :: forall message. String -> HH.Child message
sshLink activeSection =
  HH.a
    [ HP.href (Route.sshPath unit)
    , HP.ariaCurrent (if activeSection == "ssh" then "page" else "false")
    , HP.class_ (linkClass (activeSection == "ssh"))
    ] [ HH.text "SSH" ]

view :: forall message. Input message -> HH.Child message
view input =
  HH.header []
    [ HH.div [ HP.class_ "w-16" ]
        [ HollowMark.view
            { interaction: input.hollowInteraction
            , mount: input.mount
            }
        ]
    , HH.div [ HP.class_ "mt-10 flex flex-wrap items-baseline gap-x-5 gap-y-2" ]
        [ HH.a
            [ HP.href (Route.homePath unit)
            , HP.class_ "font-instrument text-[18px] font-semibold tracking-tight text-[#171717] no-underline transition-colors hover:text-[#FF4B26] dark:text-neutral-100 dark:hover:text-[#FF6B4A]"
            ] [ HH.text Site.brandMark ]
        , HH.nav
            [ HP.ariaLabel "Primary navigation"
            , HP.class_ "flex items-center gap-4 text-xs leading-none"
            ]
            [ navigationLink input.activeSection Site.thoughtSection Site.thoughtSection
            , labLink input
            , sshLink input.activeSection
            , Footer.themeToggle { theme: input.theme, message: input.themeMessage }
            ]
        ]
    ]
