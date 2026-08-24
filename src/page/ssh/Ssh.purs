module Page.Ssh where

import Prelude

import App.Site as Site
import Interop.Foldkit as FK
import Interop.Foldkit.Html as HH
import Interop.Foldkit.Prop as HP

type Input =
  {}

view :: forall message. Input -> FK.Child message
view _ =
  HH.div [ HP.class_ "flex min-h-[clamp(18rem,34vh,24rem)] flex-col justify-center" ]
    [ HH.div [ HP.class_ "flex flex-col items-center space-y-3 text-center" ]
        [ HH.h1 [ HP.class_ "font-instrument text-xl text-[#171717] dark:text-neutral-100" ] [ HH.text "SSH" ]
        , HH.p [ HP.class_ "text-[12px] text-neutral-500 dark:text-neutral-400" ] [ HH.text "Access this site over SSH with:" ]
        , HH.pre [ HP.class_ "mx-auto w-fit rounded-md border border-neutral-200 bg-transparent px-3 py-2 text-left font-mono text-[11px] leading-relaxed text-neutral-700 dark:border-neutral-800 dark:text-neutral-300" ]
            [ HH.code [] [ HH.text ("ssh " <> Site.siteHost) ] ]
        ]
    ]
