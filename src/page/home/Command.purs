module Page.Home.Command where

import Prelude

import App.Site as Site
import Foldkit.Command as Foldkit
import Page.Home.Message as Message
import Platform.GitHub as GitHub
import PursTs.Effect as Fx

loadGitHub :: Foldkit.Command Message.Message
loadGitHub = Foldkit.named "LoadGitHub" { username: Site.githubUsername } \_ ->
  Fx.match (GitHub.load Site.githubUsername)
    { onFailure: const Message.FailedLoadGitHub
    , onSuccess: Message.SucceededLoadGitHub
    }
