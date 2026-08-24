module App.Model where

import App.Route as Route
import App.RouteTransition as RouteTransition
import Domain.Theme as Theme
import Page.Home.Model as Home
import Page.Post.Model as Post

type Model =
  { route :: Route.AppRoute
  , theme :: Theme.Theme
  , routeMotion :: RouteTransition.RouteMotion
  , home :: Home.Model
  , post :: Post.Model
  }

initialModel :: String -> Model
initialModel path =
  { route: Route.urlToAppRoute path
  , theme: Theme.Light
  , routeMotion: RouteTransition.Idle
  , home: Home.initialModel
  , post: Post.initialModel
  }
