module App.Route where

import Prelude

import App.Site as Site
import Data.Array as Array
import Data.String as String
import Data.String.Pattern (Pattern(..))

data AppRoute
  = Home
  | Ssh
  | Section String
  | Post String String
  | NotFound String

homeRoute :: AppRoute
homeRoute = Home

sshRoute :: AppRoute
sshRoute = Ssh

sectionRoute :: String -> AppRoute
sectionRoute = Section

postRoute :: String -> String -> AppRoute
postRoute section slug = Post section slug

notFoundRoute :: String -> AppRoute
notFoundRoute = NotFound

normalizePath :: String -> Array String
normalizePath path =
  Array.filter (_ /= "") (String.split (Pattern "/") path)

isContentSection :: String -> Boolean
isContentSection section = Array.elem section [ Site.thoughtSection, Site.labSection ]

urlToAppRoute :: String -> AppRoute
urlToAppRoute rawPath =
  let parts = normalizePath rawPath
  in case parts of
    [] -> homeRoute
    [ "ssh" ] -> sshRoute
    [ section ] | isContentSection section -> sectionRoute section
    [ section, slug ] | isContentSection section -> postRoute section slug
    _ -> notFoundRoute ("/" <> String.joinWith "/" parts)

routePath :: AppRoute -> String
routePath route = case route of
  Home -> homePath unit
  Ssh -> sshPath unit
  Section section -> sectionPath { section }
  Post section slug -> postPath { section, slug }
  NotFound path -> path

sshPath :: Unit -> String
sshPath _ = "/ssh/"

sectionPath :: { section :: String } -> String
sectionPath input = "/" <> input.section <> "/"

postPath :: { section :: String, slug :: String } -> String
postPath input = "/" <> input.section <> "/" <> input.slug <> "/"

homePath :: Unit -> String
homePath _ = "/"
