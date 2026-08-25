module App.View where

import Prelude

import App.Core (Model, hoveredLab, leftLab, selectedTheme)
import App.Mount as Mount
import App.Message as AppMessage
import App.Route as Route
import App.Site as Site
import Component.SiteHeader as SiteHeader
import Data.Maybe (Maybe(..))
import App.RouteTransition as RouteMotion
import Content.Repository as Repository
import Domain.Theme as Theme
import Foldkit.Document as Document
import Foldkit.Html as HH
import Foldkit.Html.Prop as HP
import Foldkit.Submodel as Submodel
import Page.Home as Home
import Page.Home.Model as HomeModel
import Page.NotFound as NotFound
import Page.Post as Post
import Page.Post.Message as PostMessage
import Page.Section as Section
import Page.Ssh as Ssh

routeView :: Model -> HH.Child AppMessage.Message
routeView model =
  case model.route of
    Route.Home -> Home.view
      { githubStatus: model.home.status
      , posts: map Repository.homePost Repository.posts
      , scribbleMount: Mount.randomScribble
      }
    Route.Ssh -> Ssh.view {}
    Route.Section section -> Section.view
      { section
      , posts: map Repository.sectionPost (Repository.postsInSection section)
      }
    Route.Post section slug ->
      case Repository.findPost section slug of
        Nothing -> NotFound.view { path: Repository.pathFor section slug }
        Just post ->
          let links = Repository.neighbors post
          in Submodel.submodel
            { slotId: "post"
            , model: model.post
            , view: \postModel -> Post.view
                { homePath: Route.sectionPath { section }
                , post: Repository.postPage post
                , copyStatus: postModel.copyStatus
                , copyMessage: PostMessage.ClickedCopyLink (Repository.pathFor post.section post.slug)
                , mount: Mount.ditheredImage
                , previous: links.previous
                , next: links.next
                }
            , toParentMessage: AppMessage.GotPostMessage
            }
    Route.NotFound path -> NotFound.view { path }

routeTitle :: Model -> String
routeTitle model =
  case model.route of
    Route.Home -> Site.siteName
    Route.Ssh -> "SSH - " <> Site.siteName
    Route.Section section -> section <> " - " <> Site.siteName
    Route.Post section slug -> case Repository.findPost section slug of
      Nothing -> "Not found"
      Just post -> post.title
    Route.NotFound _ -> "Not found - " <> Site.siteName

routePath :: Model -> String
routePath model = Route.routePath model.route

seaLabInteraction :: Model -> String
seaLabInteraction model =
  if activeSection model == Site.labSection then
    HomeModel.labInteractionName HomeModel.LabHovered
  else
    HomeModel.labInteractionName model.home.labInteraction

activeSection :: Model -> String
activeSection model = case model.route of
  Route.Ssh -> "ssh"
  Route.Section section -> section
  Route.Post section _ -> section
  _ -> ""

siteHeaderView :: Model -> HH.Child AppMessage.Message
siteHeaderView model = SiteHeader.view
  { activeSection: activeSection model
  , hollowInteraction: seaLabInteraction model
  , labHoveredMessage: hoveredLab
  , labLeftMessage: leftLab
  , mount: Mount.hollowMark
  , theme: model.theme
  , themeMessage: selectedTheme (Theme.toggle model.theme)
  }

pageView :: Model -> HH.Child AppMessage.Message
pageView model = HH.div
  [ HP.id "page-view"
  , HP.dataAttribute "route-motion" (RouteMotion.toString model.routeMotion)
  , HP.class_ "route-content mt-7"
  ] [ routeView model ]

seaFooterView :: Model -> HH.Child AppMessage.Message
seaFooterView model = HH.div
  [ HP.class_ "flex w-full min-h-0 flex-1 flex-col self-stretch mt-14" ]
  [ HH.div
      [ HP.id "sea-footer"
      , HP.dataAttribute "lab-interaction" (seaLabInteraction model)
      , HP.class_ "relative mt-10 flex min-h-0 w-[calc(100%+4rem)] -mx-8 max-w-none flex-1 overflow-hidden rounded-lg bg-transparent dark:bg-[#171717]"
      ]
      [ HH.canvas
          [ HP.id "sea-canvas"
          , HP.class_ "block w-full touch-none bg-transparent"
          , HP.onMount { action: Mount.seaShader }
          ] []
      ]
  ]

applicationBody :: Model -> HH.Child AppMessage.Message
applicationBody model = HH.div
  [ HP.class_ "min-h-screen bg-[#F5F5F5] text-[#171717] antialiased dark:bg-neutral-950 dark:text-neutral-100" ]
  [ HH.div
      [ HP.class_ "flex min-h-screen w-full flex-col md:h-screen md:max-h-screen md:flex-row md:overflow-hidden" ]
      [ HH.main
          [ HP.class_ "flex h-full min-h-0 min-w-0 flex-1 flex-col border-t border-[#E5E5E5] bg-white dark:border-neutral-800 dark:bg-neutral-900 md:border-t-0" ]
          [ HH.div
              [ HP.id "content-scroll"
              , HP.class_ "flex h-full min-h-0 min-h-full w-full flex-1 flex-col items-center justify-start overflow-y-auto bg-white px-8 pb-0 pt-4 dark:bg-neutral-900 md:pt-14"
              ]
              [ HH.div [ HP.class_ "w-full max-w-3xl text-left" ]
                  [ siteHeaderView model
                  , pageView model
                  ]
              , seaFooterView model
              ]
          ]
      ]
  ]

view :: Model -> Document.Document AppMessage.Message
view model =
  let pathname = routePath model
  in Document.document
      { title: routeTitle model
      , body: applicationBody model
      }
      # Document.withCanonical (Site.siteUrl <> pathname)
      # Document.withOpenGraphUrl (Site.siteUrl <> pathname)
