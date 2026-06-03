module Prerender.Pages where

import Prelude

import Types (Post, Route(..), SiteManifest, findPost, sectionFrom, sectionToString)
import Data.Maybe (Maybe(..))
import Data.Array as Array

allRoutes :: SiteManifest -> Array Route
allRoutes manifest =
  let
    sections = Array.nub $ map _.section manifest.posts
  in
    [ Home, About ]
      <> map (SectionIndex <<< sectionToString) sections
      <> map (\p -> SectionPost (sectionToString p.section) p.slug) manifest.posts

titleFor :: Array Post -> Route -> String
titleFor posts = case _ of
  Home -> "Home"
  About -> "About"
  SectionIndex s -> case s of
    "articles" -> "Articles"
    "projects" -> "Projects"
    "til" -> "TIL"
    _ -> s
  SectionPost section slug -> case findPost posts (sectionFrom section) slug of
    Nothing -> "Post"
    Just p -> p.title
