module App.Core where

import App.Update as Update
import App.Wire.Command as CommandWire
import App.Wire.Message as MessageWire
import Domain.Theme as Theme

type Message = Update.Message
type RawMessage = Update.RawMessage
type CommandSpec = Update.CommandSpec
type Model = Update.Model
type UpdateResult = Update.UpdateResult
type RuntimeUpdateResult = Update.RuntimeUpdateResult

initialModel :: String -> Model
initialModel = Update.initialModel

init :: String -> UpdateResult
init = Update.init

initInput :: { path :: String } -> RuntimeUpdateResult
initInput = Update.initInput

update :: Model -> Message -> UpdateResult
update = Update.update

updateInput :: { model :: Model, message :: RawMessage } -> RuntimeUpdateResult
updateInput = Update.updateInput

encodeResult :: UpdateResult -> RuntimeUpdateResult
encodeResult = Update.encodeResult

clickedCopyPostLink :: String -> RawMessage
clickedCopyPostLink = MessageWire.clickedCopyPostLink

clickedLink :: { requestTag :: String, requestUrl :: String, requestHref :: String } -> RawMessage
clickedLink = MessageWire.clickedLink

selectedTheme :: Theme.Theme -> RawMessage
selectedTheme = MessageWire.selectedTheme

hoveredLab :: RawMessage
hoveredLab = MessageWire.hoveredLab

leftLab :: RawMessage
leftLab = MessageWire.leftLab

isKnownMessageTag :: String -> Boolean
isKnownMessageTag = MessageWire.isKnownTag

changedUrl :: String -> RawMessage
changedUrl = MessageWire.changedUrl

messageTags :: Array String
messageTags = MessageWire.messageTags

commandTags :: Array String
commandTags = CommandWire.commandTags

routeMotionName :: Model -> String
routeMotionName = Update.routeMotionName

themeName :: Model -> String
themeName = Update.themeName
