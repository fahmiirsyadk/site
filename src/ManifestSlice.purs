module ManifestSlice
  ( manifestForSiteIndexJson
  , sliceManifest
  , slicePostForRoute
  , stripPost
  , stripThoughtBody
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Types (Post, Route(..), SiteManifest, Thought)

stripThoughtBody :: Thought -> Thought
stripThoughtBody t = t { bodyHtml = "" }

-- | Drop heavy fields from the hydration payload. On `SectionPost`, keep `bodyBlocks` for the
-- | active article so SSR and client hydrate match (same Luna tree as `App.renderStatic`).
stripPost :: Post -> Post
stripPost p = p { bodyHtml = Nothing, bodyBlocks = [] }

slicePostForRoute :: String -> String -> Post -> Post
slicePostForRoute sec slug p =
  if p.section == sec && p.slug == slug then
    p { bodyHtml = Nothing }
  else
    stripPost p

sliceManifest :: Route -> SiteManifest -> SiteManifest
sliceManifest route manifest =
  case route of
    SectionPost sec slug ->
      manifest
        { posts = map (slicePostForRoute sec slug) manifest.posts
        , thoughts = map stripThoughtBody manifest.thoughts
        }
    _ ->
      manifest
        { posts = map stripPost manifest.posts
        , thoughts = map stripThoughtBody manifest.thoughts
        }

-- | Full index JSON: drop heavy fields; clients load bodies from per-post `/data/posts/.../*.json`.
manifestForSiteIndexJson :: SiteManifest -> SiteManifest
manifestForSiteIndexJson m =
  m { posts = map (\p -> p { bodyHtml = Nothing, bodyBlocks = [] }) m.posts }
