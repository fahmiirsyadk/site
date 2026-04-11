module Content where

import Prelude

import ManifestCodec (decodeSiteManifestString)
import Data.Either (Either)
import Types (Post, SiteManifest)
import Effect (Effect)
import Node.Encoding as Enc
import Node.FS.Sync as FS
import Node.Path (concat)
import Node.Process (cwd)

postsJsonPath :: Effect String
postsJsonPath = do
  projectRoot <- cwd
  pure $ concat [ projectRoot, "generated/posts.json" ]

readPosts :: Effect (Either String (Array Post))
readPosts = do
  jsonPath <- postsJsonPath
  content <- FS.readTextFile Enc.UTF8 jsonPath
  pure $ decodeSiteManifestString content <#> (\m -> m.posts)

readSiteManifest :: Effect (Either String SiteManifest)
readSiteManifest = do
  jsonPath <- postsJsonPath
  content <- FS.readTextFile Enc.UTF8 jsonPath
  pure $ decodeSiteManifestString content