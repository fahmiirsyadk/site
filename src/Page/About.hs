{-# LANGUAGE OverloadedStrings #-}
module Page.About (aboutPage) where

import Lucid

aboutPage :: Html ()
aboutPage = do
  div_ [class_ "space-y-5"] $ do
    h1_ [class_ "text-[12px] leading-[1.7] font-semibold text-[#171717] dark:text-neutral-100"]
      "About"
    p_ [class_ "text-[12px] leading-[1.7] text-neutral-600 dark:text-neutral-400"]
      "This is a static site generated with Slick + Lucid + Shake in Haskell. Notes, projects, and experiments in public."