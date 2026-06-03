module BuildContent.Discover
  ( ContentFile
  , discoverMarkdownFiles
  ) where

import Prelude

import Data.Array as Array
import Data.Traversable (traverse)
import Data.Maybe (Maybe(..))
import Data.String as String
import Effect (Effect)
import Node.FS.Stats as Stats
import Node.FS.Sync as FS
import Node.Path as Path
import Node.Process as Proc

type ContentFile =
  { section :: String
  , filePath :: String
  , baseName :: String
  }

isMd :: String -> Boolean
isMd name =
  let l = String.length name
  in l >= 3 && String.drop (l - 3) name == ".md"

discoverMarkdownFiles :: Effect (Array ContentFile)
discoverMarkdownFiles = do
  root <- Proc.cwd
  let contentDir = Path.concat [ root, "content" ]
  ok <- FS.exists contentDir
  if not ok then
    pure []
  else
    walk contentDir Nothing

walk :: String -> Maybe String -> Effect (Array ContentFile)
walk dir mbSection = do
  names <- FS.readdir dir
  chunks <- traverse (processEntry dir mbSection) names
  pure $ Array.concat chunks

processEntry :: String -> Maybe String -> String -> Effect (Array ContentFile)
processEntry dir mbSection name = do
  let full = Path.concat [ dir, name ]
  st <- FS.stat full
  if Stats.isDirectory st then
    case mbSection of
      Nothing -> walk full (Just name)
      Just sec -> walk full (Just sec)
  else if Stats.isFile st && isMd name then case mbSection of
    Nothing -> pure []
    Just sec ->
      let base = String.take (String.length name - 3) name
      in
        pure [ { section: sec, filePath: full, baseName: base } ]
  else
    pure []
