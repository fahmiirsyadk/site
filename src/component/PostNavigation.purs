module Component.PostNavigation where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Foldkit.Html as HH
import Foldkit.Html.Prop as HP

type Link =
  { label :: String
  , title :: String
  , path :: String
  , right :: Boolean
  }

view :: forall message. { previous :: Array Link, next :: Array Link } -> HH.Child message
view input =
  if Array.null input.previous && Array.null input.next then
    HH.empty
  else
    HH.nav
      [ HP.ariaLabel "Post navigation"
      , HP.class_ "mt-12 grid grid-cols-2 gap-3 border-t border-[#E5E5E5] pt-6 dark:border-neutral-800"
      ]
      [ slot input.previous
      , slot input.next
      ]

slot :: forall message. Array Link -> HH.Child message
slot links =
  case Array.head links of
    Nothing -> HH.span [] []
    Just link ->
      HH.a
        [ HP.href link.path
        , HP.class_ ("group flex flex-col gap-1 rounded-md border border-[#E5E5E5] px-4 py-3 no-underline transition-colors hover:border-[#FF4B26] dark:border-neutral-800 " <> if link.right then "items-end text-right" else "items-start text-left")
        ]
        [ HH.span [ HP.class_ "text-[10px] uppercase tracking-[0.07em] text-neutral-600 dark:text-neutral-400" ] [ HH.text link.label ]
        , HH.span [ HP.class_ "font-instrument text-[15px] leading-snug text-[#171717] group-hover:text-[#FF4B26] dark:text-neutral-200 dark:group-hover:text-[#FF6B4A]" ] [ HH.text link.title ]
        ]
