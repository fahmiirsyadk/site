module Content.Repository where

import App.Route as Route
import Data.Maybe (Maybe(..))
import Domain.Content as Content
import Interop.Content as Interop

type Post = Content.Post

type HomePost =
  { slug :: String
  , path :: String
  , title :: String
  , date :: String
  , dateLabel :: String
  }

type SectionPost =
  { slug :: String
  , title :: String
  , path :: String
  , date :: String
  , dateLabel :: String
  }

type PostPage =
  { title :: String
  , date :: String
  , dateLabel :: String
  , html :: String
  , banner :: String
  , toc :: Array Interop.TocEntry
  }


type Link =
  { label :: String
  , title :: String
  , path :: String
  , right :: Boolean
  }

posts :: Array Post
posts = Content.publishedPosts Interop.posts

pathFor :: String -> String -> String
pathFor section slug = Route.postPath { section, slug }

isSection :: String -> Boolean
isSection = Route.isContentSection

postsInSection :: String -> Array Post
postsInSection = Content.postsInSection posts

findPost :: String -> String -> Maybe Post
findPost = Content.findPost posts

metadataForPath :: String -> Content.DocumentMetadata
metadataForPath = Content.metadataForPath posts

homePost :: Post -> HomePost
homePost post =
  { slug: post.slug
  , path: pathFor post.section post.slug
  , title: post.title
  , date: post.date
  , dateLabel: Interop.formatDate post.date
  }

sectionPost :: Post -> SectionPost
sectionPost post =
  { slug: post.slug
  , title: post.title
  , path: pathFor post.section post.slug
  , date: post.date
  , dateLabel: Interop.formatDate post.date
  }

postPage :: Post -> PostPage
postPage post =
  { title: post.title
  , date: post.date
  , dateLabel: Interop.formatDate post.date
  , html: post.html
  , banner: post.banner
  , toc: post.toc
  }

postLink :: Boolean -> Post -> Link
postLink right post =
  { label: if right then "Newer" else "Older"
  , title: post.title
  , path: pathFor post.section post.slug
  , right
  }

neighbors :: Post -> { previous :: Array Link, next :: Array Link }
neighbors post =
  let neighboring = Content.neighboringPosts posts post
  in
    { previous: maybeLink false neighboring.older
    , next: maybeLink true neighboring.newer
    }

maybeLink :: Boolean -> Maybe Post -> Array Link
maybeLink right maybePost = case maybePost of
  Nothing -> []
  Just post -> [ postLink right post ]
