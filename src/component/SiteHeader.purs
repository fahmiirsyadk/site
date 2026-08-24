module Component.SiteHeader where

import Prelude

import App.Route as Route
import App.Site as Site
import Component.HollowMark as HollowMark
import Domain.Theme as Theme
import Component.Footer as Footer
import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Mount (MountAction)
import Interop.Foldkit.Prop as HP

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

navigationLink :: forall message. String -> String -> String -> FK.Child message
navigationLink activeSection section label =
  HH.a
    [ HP.attr "href" (Route.sectionPath { section })
    , HP.attr "aria-current" (if activeSection == section then "page" else "false")
    , HP.class_ (linkClass (activeSection == section))
    ] [ HH.text label ]

labLink :: forall message. Input message -> FK.Child message
labLink input =
  HH.a
    [ HP.attr "href" (Route.sectionPath { section: Site.labSection })
    , HP.attr "aria-current" (if input.activeSection == Site.labSection then "page" else "false")
    , HP.attr "data-lab-link" "true"
    , HP.onMouseEnter { message: input.labHoveredMessage }
    , HP.onMouseLeave { message: input.labLeftMessage }
    , HP.class_ (linkClass (input.activeSection == Site.labSection))
    ] [ HH.text Site.labSection ]

sshLink :: forall message. String -> FK.Child message
sshLink activeSection =
  HH.a
    [ HP.attr "href" (Route.sshPath unit)
    , HP.attr "aria-current" (if activeSection == "ssh" then "page" else "false")
    , HP.class_ (linkClass (activeSection == "ssh"))
    ] [ HH.text "SSH" ]

view :: forall message. Input message -> FK.Child message
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
            [ HP.attr "href" (Route.homePath unit)
            , HP.class_ "font-instrument text-[18px] font-semibold tracking-tight text-[#171717] no-underline transition-colors hover:text-[#FF4B26] dark:text-neutral-100 dark:hover:text-[#FF6B4A]"
            ] [ HH.text Site.brandMark ]
        , HH.nav
            [ HP.attr "aria-label" "Primary navigation"
            , HP.class_ "flex items-center gap-4 text-xs leading-none"
            ]
            [ navigationLink input.activeSection Site.thoughtSection Site.thoughtSection
            , labLink input
            , sshLink input.activeSection
            , Footer.themeToggle { theme: input.theme, message: input.themeMessage }
            ]
        ]
    ]
