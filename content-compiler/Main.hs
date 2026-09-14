{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Function (on)
import Data.List (groupBy, sort, sortOn)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (listDirectory)
import System.Environment (getArgs)
import Site.Content.Compiler.Frontmatter (compilePost)
import Site.Content.Compiler.Emit (emitPosts)
import Site.Content.Compiler.Highlight (highlightPosts)
import Site.Content.Types (Post (..))

main :: IO ()
main = do
  args <- getArgs
  names <- sort <$> listDirectory "content"
  posts <- mapM (compileOne . ("content/" <>)) (filter (hasSuffix ".md") names) >>= mapM highlightPost
  case duplicateRoutes posts of
    [] -> pure ()
    duplicates -> fail ("duplicate content routes: " <> show duplicates)
  emitPosts (case args of output : _ -> output; [] -> "generated/Site/Content/Generated.hs") posts
  where
    compileOne path = do
      source <- TIO.readFile path
      case compilePost path source of
        Left errorMessage -> fail errorMessage
        Right post -> pure post
    highlightPost post = do
      highlighted <- highlightPosts (postBody post)
      case highlighted of
        Left errorMessage -> fail (T.unpack (postSlug post) <> ": " <> errorMessage)
        Right body -> pure post { postBody = body }
    hasSuffix suffix value = suffix == reverse (take (length suffix) (reverse value))
    duplicateRoutes values =
      [ (postSection post, postSlug post)
      | group <- groupBy ((==) `on` routeKey) (sortByRoute values)
      , length group > 1
      , post <- take 1 group
      ]
    routeKey post = (postSection post, postSlug post)
    sortByRoute = sortOn routeKey
