{-# LANGUAGE OverloadedStrings #-}
module Page.Post (postPage) where

import Lucid
import Data.Maybe (isNothing)
import Data.Text (Text)
import qualified Data.Text as T
import Site.Types (Post(..), PostSummary(..), calLabel)
import Site.Theme (mk, rawHtml)

-- | Cover image with an animated "dappled light" canvas overlay (see dappled.js).
coverHeader :: Post -> Html ()
coverHeader p = case pBanner p of
  Just b | not (null b) ->
    div_ [class_ "post-cover overflow-hidden rounded-lg"] $ do
      img_ [src_ (T.pack b), alt_ (T.pack (pTitle p)), mk "loading" "eager"]
      div_ [class_ "cover-scene", mk "aria-hidden" "true"] (mempty :: Html ())
  _ -> mempty

-- | A single previous/next link cell.
postNavLink :: Text -> Bool -> PostSummary -> Html ()
postNavLink label alignRight ps =
  a_ [ href_ ("/" <> psSection ps <> "/" <> psSlug ps <> "/")
     , class_ $ "group flex flex-col gap-1 rounded-md border border-[#E5E5E5] px-4 py-3 no-underline transition-colors hover:border-[#FF4B26] dark:border-neutral-800"
                <> if alignRight then " text-right items-end" else " text-left items-start"
     ] $ do
    span_ [class_ "text-[10px] uppercase tracking-[0.07em] text-neutral-400"] (toHtml label)
    span_ [class_ "font-instrument text-[15px] leading-snug text-[#171717] transition-colors group-hover:text-[#FF4B26] dark:text-neutral-200 dark:group-hover:text-[#FF6B4A]"]
      (toHtml (psTitle ps))

-- | Previous (older) / next (newer) navigation between posts in a section.
postNav :: Maybe PostSummary -> Maybe PostSummary -> Html ()
postNav older newer
  | isNothing older && isNothing newer = mempty
  | otherwise =
    nav_ [ class_ "mt-12 grid grid-cols-2 gap-3 border-t border-[#E5E5E5] pt-6 dark:border-neutral-800"
         , mk "aria-label" "Post navigation"
         ] $ do
      maybe (span_ mempty) (postNavLink "Previous" False) older
      maybe (span_ mempty) (postNavLink "Next" True) newer

postPage :: Post -> Maybe PostSummary -> Maybe PostSummary -> Html ()
postPage p older newer =
  article_ [class_ "min-w-0 space-y-6 overflow-x-auto"] $ do
    coverHeader p
    div_ [class_ "flex w-full items-center gap-3 text-[12px] leading-[1.7]"] $ do
      h1_ [class_ "shrink-0 font-instrument text-xl leading-tight text-[#171717] dark:text-neutral-100"] (toHtml (pTitle p))
      span_ [class_ "min-h-px min-w-[1.5rem] flex-1 border-b border-solid border-neutral-300 dark:border-neutral-600"] mempty
      span_ [ class_ "shrink-0 text-right text-neutral-500"
            , mk "data-relative-date" (T.pack (pDate p))
            ] (toHtml (calLabel (pDate p)))
    div_ [class_ "prose prose-sm prose-neutral dark:prose-invert max-w-none prose-headings:font-instrument prose-headings:text-[#171717] dark:prose-headings:text-neutral-100 prose-p:text-neutral-700 dark:prose-p:text-neutral-300 prose-li:text-neutral-700 dark:prose-li:text-neutral-300 prose-a:text-[#FF4B26] prose-a:no-underline hover:prose-a:underline prose-ul:list-none prose-ol:list-none"]
      (rawHtml (T.pack (pContent p)))
    postNav older newer
