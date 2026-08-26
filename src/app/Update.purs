module App.Update where

import Prelude

import App.Command as Command
import App.Message as AppMessage
import App.Model as AppModel
import App.Route as Route
import App.RouteTransition as RouteMotion
import Content.Repository as Repository
import Data.Maybe (Maybe(..))
import Domain.Theme as Theme
import Foldkit.Command as FoldkitCommand
import Foldkit.Update as FoldkitUpdate
import Page.Home.Command as HomeCommand
import Page.Home.Model as HomeModel
import Page.Home.Update as HomeUpdate
import Page.Post.Message as PostMessage
import Page.Post.Update as PostUpdate

type Message = AppMessage.Message
type Model = AppModel.Model

type UpdateResult = FoldkitUpdate.Return Model Message

initialModel :: String -> Model
initialModel = AppModel.initialModel

init :: String -> UpdateResult
init path =
  let model = initialModel path
  in result model
      [ Command.readTheme
      , FoldkitCommand.mapMessage HomeCommand.loadGitHub AppMessage.GotHomeMessage
      , Command.syncDocumentMetadata (Repository.metadataForPath (Route.routePath model.route))
      ]

update :: Model -> Message -> UpdateResult
update model message = case message of
  AppMessage.CompletedNavigateInternal -> result model []
  AppMessage.CompletedNavigateHeading -> result model []
  AppMessage.CompletedScrollToHeading -> result model []
  AppMessage.CompletedScrollToProgress -> result model []
  AppMessage.StartedRouteEntry -> result (model { routeMotion = RouteMotion.Idle }) []
  AppMessage.GotHomeMessage childMessage ->
    let childResult = HomeUpdate.update model.home childMessage
    in result (model { home = childResult.model }) (lifted AppMessage.GotHomeMessage childResult).commands
  AppMessage.ClickedCopyPostLink url ->
    let childResult = PostUpdate.update model.post (PostMessage.ClickedCopyLink url)
    in result (model { post = childResult.model }) (lifted AppMessage.GotPostMessage childResult).commands
  AppMessage.GotPostMessage childMessage ->
    let childResult = PostUpdate.update model.post childMessage
    in result (model { post = childResult.model }) (lifted AppMessage.GotPostMessage childResult).commands
  AppMessage.ClickedInternalLink input ->
    case input.hash of
      Just heading | input.path == Route.routePath model.route ->
        result model [ Command.navigateHeading input.path heading ]
      Just heading ->
        result
          (model { routeMotion = RouteMotion.Leaving })
          [ Command.navigateInternal (input.path <> "#" <> heading) ]
      Nothing ->
        result (model { routeMotion = RouteMotion.Leaving }) [ Command.navigateInternal input.path ]
  AppMessage.ClickedExternalLink href -> result model [ Command.loadExternal href ]
  AppMessage.ChangedUrl input ->
    if input.path == Route.routePath model.route then
      case input.hash of
        Just heading -> result model [ Command.scrollToHeading heading ]
        Nothing -> result model []
    else
      let nextHome = model.home { labInteraction = HomeModel.LabIdle }
          nextRoute = Route.urlToAppRoute input.path
          commands = [ Command.startRouteEntry
                     , Command.resetScroll
                     , Command.syncDocumentMetadata (Repository.metadataForPath (Route.routePath nextRoute))
                     ] <> case input.hash of
                       Just heading -> [ Command.scrollToHeading heading ]
                       Nothing -> []
      in result
        (model { route = nextRoute, routeMotion = RouteMotion.Entering, home = nextHome })
        commands
  AppMessage.LoadedTheme theme -> result (model { theme = theme }) []
  AppMessage.SelectedTheme theme -> result (model { theme = theme }) [ Command.persistTheme theme ]
  AppMessage.CompletedLoadExternal -> result model []
  AppMessage.CompletedMountSeaShader -> result model []
  AppMessage.CompletedMountHollowMark -> result model []
  AppMessage.CompletedMountRandomScribble -> result model []
  AppMessage.FailedMountSeaShader -> result model []
  AppMessage.FailedMountHollowMark -> result model []
  AppMessage.FailedMountRandomScribble -> result model []
  AppMessage.CompletedPersistTheme -> result model []
  AppMessage.FailedPersistTheme -> result model []
  AppMessage.CompletedResetScroll -> result model []
  AppMessage.FailedResetScroll -> result model []
  AppMessage.CompletedSyncDocumentMetadata -> result model []
  AppMessage.FailedSyncDocumentMetadata -> result model []

lifted
  :: forall childModel childMessage
   . (childMessage -> Message)
   -> FoldkitUpdate.Return childModel childMessage
   -> FoldkitUpdate.Return childModel Message
lifted toParent = FoldkitUpdate.mapCommands toParent

result :: Model -> Array (FoldkitCommand.Command Message) -> UpdateResult
result model commands = { model, commands }

routeMotionName :: Model -> String
routeMotionName model = RouteMotion.toString model.routeMotion

themeName :: Model -> String
themeName model = Theme.toString model.theme
