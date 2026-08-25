module App.Core where

import App.Message as AppMessage
import App.Update as Update
import Domain.Theme as Theme
import Foldkit.Runtime (Url, UrlRequest(..))
import Page.Home.Message as HomeMessage

type Message = Update.Message
type Model = Update.Model
type UpdateResult = Update.UpdateResult

initialModel :: String -> Model
initialModel = Update.initialModel

init :: String -> UpdateResult
init = Update.init

update :: Model -> Message -> UpdateResult
update = Update.update

clickedCopyPostLink :: String -> Message
clickedCopyPostLink = AppMessage.ClickedCopyPostLink

clickedLink :: UrlRequest -> Message
clickedLink request = case request of
  Internal input -> AppMessage.ClickedInternalLink (urlPath input.url)
  External input -> AppMessage.ClickedExternalLink input.href

selectedTheme :: Theme.Theme -> Message
selectedTheme = AppMessage.SelectedTheme

hoveredLab :: Message
hoveredLab = AppMessage.GotHomeMessage HomeMessage.HoveredLab

leftLab :: Message
leftLab = AppMessage.GotHomeMessage HomeMessage.LeftLab

changedUrl :: Url -> Message
changedUrl url = AppMessage.ChangedUrl (urlPath url)

urlPath :: Url -> String
urlPath url = url.pathname

routeMotionName :: Model -> String
routeMotionName = Update.routeMotionName

themeName :: Model -> String
themeName = Update.themeName
