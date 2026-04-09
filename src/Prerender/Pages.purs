module Prerender.Pages where

import Prelude

import Types (Post, Route(..), SiteManifest)
import Data.Maybe (Maybe(..))
import Data.Array as Array

allRoutes :: SiteManifest -> Array Route
allRoutes manifest =
  let
    sections = Array.nub $ map _.section manifest.posts
  in
    [ Home, About ]
      <> map SectionIndex sections
      <> map (\p -> SectionPost p.section p.slug) manifest.posts

titleFor :: Array Post -> Route -> String
titleFor posts = case _ of
  Home -> "Home"
  About -> "About"
  SectionIndex s -> case s of
    "articles" -> "Articles"
    "projects" -> "Projects"
    "til" -> "TIL"
    _ -> s
  SectionPost section slug -> case findPostBySectionAndSlug posts section slug of
    Nothing -> "Post"
    Just p -> p.title

findPostBySectionAndSlug :: Array Post -> String -> String -> Maybe Post
findPostBySectionAndSlug posts section slug =
  Array.find (\p -> p.slug == slug && p.section == section) posts
