module Prerender.Pages where

import Prelude

import Types (Post, Route(..), SiteManifest)
import Data.Array (filter, head)
import Data.Maybe (Maybe(..))

allRoutes :: SiteManifest -> Array Route
allRoutes manifest =
  [ Home, About, ArticlesIndex, ProjectsIndex ] 
  <> map (Article <<< _.slug) manifest.articles
  <> map (Project <<< _.slug) manifest.projects
  <> map Collection manifest.tags

titleFor :: Array Post -> Route -> String
titleFor posts = case _ of
  Home -> "Home"
  About -> "About"
  ArticlesIndex -> "Articles"
  ProjectsIndex -> "Projects"
  Collection tag -> "Collection: " <> tag
  Article slug -> case findPostBySlug slug posts of
    Nothing -> "Article"
    Just p -> p.title
  Project slug -> case findPostBySlug slug posts of
    Nothing -> "Project"
    Just p -> p.title

findPostBySlug :: String -> Array Post -> Maybe Post
findPostBySlug slug posts = 
  head $ filter (_.slug >>> (==) slug) posts