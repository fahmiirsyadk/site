-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | One section's index: its name and every published post in it. Ported from
-- the source's @Page.Section@.
module Site.View.Section
  ( sectionView
  ) where
-----------------------------------------------------------------------------
import           Miso (text)
import           Miso.Html.Element as H
import           Miso.Html.Property as P
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.Content (Post)
import qualified Site.Content as Content
import           Site.Route (Route (..))
import           Site.View.Link (Node, internalLink)
-----------------------------------------------------------------------------
sectionView :: MisoString -> Node context
sectionView section =
  H.div_
    [ P.class_ "space-y-6" ]
    [ H.h1_
        [ P.class_ "text-[12px] font-semibold leading-[1.7] text-[#171717] dark:text-neutral-100" ]
        [ text section ]
    , case posts of
        [] -> H.p_
          [ P.class_ "text-[12px] text-neutral-600 dark:text-neutral-400" ]
          [ text "Nothing here yet." ]
        _ -> H.div_
          [ P.class_ "flex w-full flex-col" ]
          (map postPreview posts)
    ]
  where
    posts = Content.postsInSection section
-----------------------------------------------------------------------------
postPreview :: Post -> Node context
postPreview post =
  H.div_
    [ P.class_ "flex w-full items-center gap-3 py-2 text-[12px] leading-[1.7]" ]
    [ internalLink (Post (Content.postSection post) (Content.postSlug post))
        [ P.class_ "shrink-0 font-instrument text-[16px] leading-[1.3] text-[#171717] no-underline hover:text-[#FF4B26] dark:text-neutral-200 dark:hover:text-[#FF6B4A]" ]
        [ text (Content.postTitle post) ]
    , H.span_
        [ P.class_ "min-h-px min-w-6 flex-1 border-b border-neutral-300 dark:border-neutral-600" ]
        []
    , H.span_
        [ P.data_ "relative-date" (Content.postDate post)
        , P.class_ "shrink-0 whitespace-nowrap text-right text-neutral-600 dark:text-neutral-400"
        ]
        [ text (Content.postDateLabel post) ]
    ]
