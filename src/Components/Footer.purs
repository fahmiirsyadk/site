module Components.Footer where

import Luna.Html as H
import Luna.Html (Html)

footer :: forall i. Html i
footer =
  H.footer
    [ H.classes [ "mt-10", "border-t", "border-[#E5E5E5]", "pt-4", "text-[12px]", "text-neutral-500" ] ]
    [ H.text "Built with Luna · design pass v1" ]