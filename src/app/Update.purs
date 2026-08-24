module App.Update where

import Prelude

import App.Command as Command
import App.Message as AppMessage
import App.Model as AppModel
import App.Route as Route
import App.RouteTransition as RouteMotion
import App.Wire.Command as CommandWire
import App.Wire.Message as MessageWire
import Content.Repository as Repository
import Domain.Theme as Theme
import Page.Home.Command as HomeCommand
import Page.Home.Model as HomeModel
import Page.Home.Update as HomeUpdate
import Page.Post.Message as PostMessage
import Page.Post.Update as PostUpdate

type Message = AppMessage.Message
type RawMessage = MessageWire.RawMessage
type CommandSpec = CommandWire.RawCommand
type Model = AppModel.Model

type UpdateResult =
  { model :: Model
  , commands :: Array Command.Command
  }

type RuntimeUpdateResult =
  { model :: Model
  , commands :: Array CommandSpec
  }

initialModel :: String -> Model
initialModel = AppModel.initialModel

init :: String -> UpdateResult
init path =
  let model = initialModel path
  in { model
     , commands:
      [ Command.ReadTheme
      , Command.fromHome HomeCommand.LoadGitHub
      , Command.SyncDocumentMetadata (Repository.metadataForPath (Route.routePath model.route))
      ]
     }

initInput :: { path :: String } -> RuntimeUpdateResult
initInput input = encodeResult (init input.path)

update :: Model -> Message -> UpdateResult
update model message = case message of
  AppMessage.CompletedNavigateInternal -> result model []
  AppMessage.FailedNavigateInternal -> result (model { routeMotion = RouteMotion.Idle }) []
  AppMessage.StartedRouteEntry -> result (model { routeMotion = RouteMotion.Idle }) []
  AppMessage.GotHomeMessage childMessage ->
    let childResult = HomeUpdate.update model.home childMessage
    in result
      (model { home = childResult.model })
      (map Command.fromHome childResult.commands)
  AppMessage.ClickedCopyPostLink url ->
    let childResult = PostUpdate.update model.post (PostMessage.ClickedCopyLink url)
    in result
      (model { post = childResult.model })
      (map Command.fromPost childResult.commands)
  AppMessage.GotPostMessage childMessage ->
    let childResult = PostUpdate.update model.post childMessage
    in result
      (model { post = childResult.model })
      (map Command.fromPost childResult.commands)
  AppMessage.ClickedInternalLink url -> result (model { routeMotion = RouteMotion.Leaving }) [ Command.NavigateInternal url ]
  AppMessage.ClickedExternalLink href -> result model [ Command.LoadExternal href ]
  AppMessage.ChangedUrl url ->
    let nextHome = model.home { labInteraction = HomeModel.LabIdle }
    in result
      (model { route = Route.urlToAppRoute url, routeMotion = RouteMotion.Entering, home = nextHome })
      [ Command.StartRouteEntry
      , Command.ResetScroll
      , Command.SyncDocumentMetadata (Repository.metadataForPath (Route.routePath (Route.urlToAppRoute url)))
      ]
  AppMessage.LoadedTheme theme -> result (model { theme = theme }) []
  AppMessage.SelectedTheme theme -> result (model { theme = theme }) [ Command.PersistTheme theme ]
  AppMessage.CompletedLoadExternal -> result model []
  AppMessage.CompletedMountSeaShader -> result model []
  AppMessage.CompletedMountDitheredImage -> result model []
  AppMessage.CompletedMountHollowMark -> result model []
  AppMessage.CompletedMountRandomScribble -> result model []
  AppMessage.CompletedPersistTheme -> result model []
  AppMessage.CompletedResetScroll -> result model []
  AppMessage.CompletedSyncDocumentMetadata -> result model []
  AppMessage.Unknown _ -> result model []
  where
  result nextModel commands = { model: nextModel, commands }

updateInput :: { model :: Model, message :: RawMessage } -> RuntimeUpdateResult
updateInput input = encodeResult (update input.model (MessageWire.decode input.message))

encodeResult :: UpdateResult -> RuntimeUpdateResult
encodeResult result =
  { model: result.model
  , commands: map CommandWire.encode result.commands
  }

routeMotionName :: Model -> String
routeMotionName model = RouteMotion.toString model.routeMotion

themeName :: Model -> String
themeName model = Theme.toString model.theme
