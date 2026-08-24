module Interop.Foldkit.Runtime where

import Prelude

import App.Wire.Command as CommandWire
import App.Wire.Message as MessageWire
import Data.Function.Uncurried (Fn1, runFn1)
import Effect (Effect)
import Interop.Foldkit (Html, HtmlBuilder)

type UpdateResult model =
  { model :: model
  , commands :: Array CommandWire.RawCommand
  }

type Document message =
  { title :: String
  , canonical :: String
  , ogUrl :: String
  , body :: Html message
  }

type RuntimeApp model message =
  { init :: String -> UpdateResult model
  , update :: { model :: model, message :: message } -> UpdateResult model
  , view :: model -> HtmlBuilder message -> Document message
  , clickedLink :: { requestTag :: String, requestUrl :: String, requestHref :: String } -> message
  , changedUrl :: String -> message
  , isKnownMessageTag :: String -> Boolean
  , messageConstructors :: MessageWire.MessageConstructors
  }

foreign import startImpl :: forall model message. Fn1 (RuntimeApp model message) (Effect Unit)

start :: forall model message. RuntimeApp model message -> Effect Unit
start app = runFn1 startImpl app
