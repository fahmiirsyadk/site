module GfxBoot (bootOverlay) where

import Luna.Html (Html, attr, unsafeRawHtml)
import Luna.Html as H

-- | Full-screen boot: red mask on canvas with transparent holes (`public/gfx-boot.js`). Emitted only in prerendered HTML via `App.ssgBodyHtml` (not client VDOM).
-- | No underlay — holes show `#app` beneath. `gfx-boot.js` syncs an SVG mask so chrome matches the canvas grid.
bootOverlay :: forall i. Html i
bootOverlay =
  H.div
    [ H.id_ "gfx-boot-overlay"
    , H.classes
        [ "gfx-boot-overlay"
        , "pointer-events-auto"
        , "fixed"
        , "inset-0"
        , "z-[2000]"
        , "overflow-hidden"
        , "bg-transparent"
        , "text-white"
        ]
    , attr "role" "status"
    , attr "aria-label" "Loading graphics"
    ]
    [ H.canvas
        [ H.id_ "gfx-boot-canvas"
        , H.classes
            [ "absolute"
            , "inset-0"
            , "z-[2]"
            , "block"
            , "h-screen"
            , "w-screen"
            , "bg-[#ff0000]"
            , "[image-rendering:pixelated]"
            , "[image-rendering:crisp-edges]"
            , "pointer-events-none"
            ]
        , attr "aria-hidden" "true"
        ]
    , unsafeRawHtml
        """
<svg class="absolute inset-0 z-0 h-full w-full overflow-hidden opacity-0 pointer-events-none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false">
  <defs>
    <mask id="gfx-boot-chrome-cut-mask" maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse" mask-type="luminance" x="0" y="0" width="100%" height="100%">
      <rect id="gfx-boot-mask-white" x="0" y="0" width="100%" height="100%" fill="white"/>
      <g id="gfx-boot-mask-holes"></g>
    </mask>
  </defs>
</svg>
"""
    , H.div
        [ H.classes [ "absolute", "inset-0", "z-[3]", "pointer-events-none" ] ]
        [ H.div
            [ H.id_ "gfx-boot-chrome"
            , H.classes [ "absolute", "inset-0", "text-white", "[text-shadow:none]", "isolate", "[transform:translateZ(0)]", "font-instrument" ]
            ]
            [ H.div
                [ H.classes
                    [ "absolute"
                    , "top-[46px]"
                    , "left-0"
                    , "origin-top-left"
                    , "-rotate-90"
                    , "-translate-x-full"
                    , "text-[12px]"
                    , "tracking-[0.04em]"
                    , "font-medium"
                    , "whitespace-nowrap"
                    , "max-md:top-[34px]"
                    , "max-md:text-[11px]"
                    ]
                ]
                [ H.text "GRAPHICS BOOT "
                , H.span [ H.id_ "gfx-boot-counter" ] [ H.text "00" ]
                , H.text "/50"
                ]
            , H.div
                [ H.classes
                    [ "absolute"
                    , "left-8"
                    , "bottom-7"
                    , "text-[clamp(44px,8vw,108px)]"
                    , "leading-[0.82]"
                    , "font-medium"
                    , "tracking-[-0.03em]"
                    , "uppercase"
                    , "max-md:left-5"
                    , "max-md:bottom-[22px]"
                    , "max-md:text-[clamp(32px,11vw,56px)]"
                    ]
                ]
                [ H.span [ H.id_ "gfx-boot-progress" ] [ H.text "0%" ] ]
            ]
        ]
    ]
