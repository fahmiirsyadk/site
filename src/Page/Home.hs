{-# LANGUAGE OverloadedStrings #-}
module Page.Home (homePage) where

import Lucid
import Site.Types (PostSummary(..))
import Site.Component (postPreviewRow)

homePage :: [PostSummary] -> Html ()
homePage posts =
  div_ [class_ "space-y-6"] $ do
    p_ [class_ "text-[12px] text-neutral-500"] "Latest posts"
    if null posts
      then p_ [class_ "text-[12px] text-neutral-500"] "No posts yet."
      else div_ [class_ "flex w-full flex-col"] $ mapM_ row posts
  where
    row ps = postPreviewRow
               ("/" <> psSection ps <> "/" <> psSlug ps <> "/")
               (psTitle ps)
               (psDate ps)
               (psRel ps)
