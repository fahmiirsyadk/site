{-# LANGUAGE OverloadedStrings #-}
module Page.Section (sectionPage) where

import Lucid
import qualified Data.Text as T
import Site.Types (PostSummary(..))
import Site.Component (postPreviewRow)

sectionPage :: T.Text -> [PostSummary] -> Html ()
sectionPage section posts = do
  div_ [class_ "space-y-6"] $ do
    h1_ [class_ "text-[12px] font-semibold leading-[1.7] text-[#171717] dark:text-neutral-100"]
      (toHtml section)
    if null posts
      then p_ [class_ "text-[12px] text-neutral-500"] "Nothing here yet."
      else div_ [class_ "flex w-full flex-col"] $ mapM_ row posts
  where
    row ps = postPreviewRow
               ("/" <> psSection ps <> "/" <> psSlug ps <> "/")
               (psTitle ps)
               (psDate ps)
               (psRel ps)