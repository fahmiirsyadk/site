{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (forM, forM_)
import Data.List (sortOn, stripPrefix, findIndex)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Text.Read (readMaybe)
import Development.Shake
import Development.Shake.FilePath
import Slick
import Slick.Pandoc
import Text.Pandoc.Options (ReaderOptions(..), enableExtension, Extension(Ext_footnotes))
import Lucid (renderText, Html)
import System.Environment (getArgs)
import qualified Dev
import Site.Types
import Site.Layout (baseLayout)
import Page.Home (homePage)
import Page.Post (postPage)
import Page.Section (sectionPage)
import Page.About (aboutPage)

siteName, siteDescription, defaultOgImage :: Text
siteName        = "Faah"
siteDescription = "Notes on systems, software, and the long arc of building things that last."
defaultOgImage  = "/assets/og/default.png"

contentDir :: FilePath
contentDir = "site/content"

contentGlob :: FilePath
contentGlob = "site/content/*/*.md"

-- | Derive the section token from the content path (e.g. "articles").
sectionOfPath :: FilePath -> Text
sectionOfPath srcPath = T.pack (takeSection srcPath)
  where takeSection = takeBaseName . takeDirectory

-- | Output path for a post: build/<section>/<slug>/index.html
postOutPath :: FilePath -> FilePath
postOutPath srcPath =
  let section = takeBaseName (takeDirectory srcPath)
      slug = takeBaseName srcPath
  in "build" </> section </> slug </> "index.html"

-- | Section index output: build/<section>/index.html
sectionOutPath :: Text -> FilePath
sectionOutPath section = "build" </> T.unpack section </> "index.html"

renderHtml :: HeadInfo -> Html () -> TL.Text
renderHtml hi body = "<!DOCTYPE html>\n" `TL.append` renderText (baseLayout hi False body)

-- | Markdown reader options: Slick's defaults plus Pandoc footnotes ([^1]).
markdownReaderOpts :: ReaderOptions
markdownReaderOpts = defaultMarkdownOptions
  { readerExtensions = enableExtension Ext_footnotes (readerExtensions defaultMarkdownOptions) }

loadPost :: FilePath -> Action Post
loadPost srcPath = do
  fileContent <- readFile' srcPath
  postData <- markdownToHTMLWithOpts markdownReaderOpts defaultHtml5Options (T.pack fileContent)
  post <- convert postData :: Action Post
  let section = T.unpack (sectionOfPath srcPath)
      slugRaw = if not (null (pSlug post)) then pSlug post else takeBaseName srcPath
  pure post { pSection = section, pSlug = slugRaw }

loadSummary :: FilePath -> Action PostSummary
loadSummary srcPath = do
  post <- loadPost srcPath
  pure PostSummary
    { psSlug = T.pack (pSlug post)
    , psTitle = T.pack (pTitle post)
    , psDate = T.pack (pDate post)
    , psRel = calLabel (pDate post)
    , psSection = sectionOfPath srcPath
    }

homeHead :: HeadInfo
homeHead = HeadInfo
  { hiTitle       = siteName
  , hiPath        = "/"
  , hiDescription = siteDescription
  , hiOgType      = "website"
  , hiOgImage     = defaultOgImage
  , hiTags        = []
  , hiPublished   = ""
  }

sectionHead :: Text -> HeadInfo
sectionHead section = HeadInfo
  { hiTitle       = section <> " - " <> siteName
  , hiPath        = "/" <> section <> "/"
  , hiDescription = siteDescription
  , hiOgType      = "website"
  , hiOgImage     = defaultOgImage
  , hiTags        = []
  , hiPublished   = ""
  }

postHead :: Post -> HeadInfo
postHead p = HeadInfo
  { hiTitle       = T.pack (pTitle p)
  , hiPath        = "/" <> T.pack (pSection p) <> "/" <> T.pack (pSlug p) <> "/"
  , hiDescription = T.pack (fromMaybe (T.unpack siteName) (pOgDescription p))
  , hiOgType      = "article"
  , hiOgImage     = T.pack (fromMaybe (T.unpack defaultOgImage) (pOgImage p))
  , hiTags        = pTags p
  , hiPublished   = T.pack (pDate p)
  }

buildHome :: Action ()
buildHome = do
  paths <- getDirectoryFiles "." [contentGlob]
  sums <- forM paths loadSummary
  let sorted = reverse (sortOn psDate sums)
  writeFile' "build/index.html" (TL.unpack (renderHtml homeHead (homePage sorted)))

buildSection :: Text -> Action ()
buildSection section = do
  let dir = contentDir </> T.unpack section
  paths <- getDirectoryFiles "." [dir </> "*.md"]
  sums <- forM paths loadSummary
  let sorted = reverse (sortOn psDate sums)
  writeFile' (sectionOutPath section) (TL.unpack (renderHtml (sectionHead section) (sectionPage section sorted)))

buildAbout :: Action ()
buildAbout = do
  let out = "build/about/index.html"
  writeFile' out (TL.unpack (renderHtml (sectionHead "about") aboutPage))

buildPostFile :: FilePath -> Action ()
buildPostFile srcPath = do
  post <- loadPost srcPath
  -- Resolve previous (older) / next (newer) siblings within the same section.
  let section = takeBaseName (takeDirectory srcPath)
  siblings <- getDirectoryFiles "." [contentDir </> section </> "*.md"]
  sums <- forM siblings loadSummary
  let sortedAsc = sortOn psDate sums          -- oldest -> newest
      curSlug = T.pack (pSlug post)
      mIdx = findIndex ((== curSlug) . psSlug) sortedAsc
      older = mIdx >>= \i -> if i > 0 then Just (sortedAsc !! (i - 1)) else Nothing
      newer = mIdx >>= \i -> if i < length sortedAsc - 1 then Just (sortedAsc !! (i + 1)) else Nothing
  writeFile' (postOutPath srcPath) (TL.unpack (renderHtml (postHead post) (postPage post older newer)))

trackAndBuild :: FilePath -> Action ()
trackAndBuild srcPath = do
  hs <- getDirectoryFiles "" ["app//*.hs", "src//*.hs"]
  need hs
  need ["gfx/gfx.js", "css/style.css"]
  buildPostFile srcPath

buildRules :: Rules ()
buildRules = do
  want ["build-site"]

  phony "build-site" $ do
    paths <- getDirectoryFiles "." [contentGlob]
    need (map postOutPath paths)
    forM_ allSections (\s -> need [sectionOutPath (sectionLabel s)])
    need ["build/index.html", "build/about/index.html", "build/_headers", "build/css/style.css", "build/gfx.js", "build/spa.js", "build/theme.js", "build/cover.js"]
    pubs <- getDirectoryFiles "." ["public/assets//**", "public/fonts//**"]
    need (map (\p -> "build" </> makeRelative "public" p) pubs)

  -- Per-post build: catch build/<section>/<slug>/index.html
  "build/*/*/index.html" %> \out -> do
    let section = takeBaseName (takeDirectory (takeDirectory out))
        slug = takeBaseName (takeDirectory out)
    if section `elem` map T.unpack (map sectionLabel allSections)
      then do
        let srcPath = contentDir </> section </> slug <.> "md"
        trackAndBuild srcPath
      else if section == "about" && slug == "index"
        then buildAbout
        else liftIO (putStrLn ("skip " ++ out))

  -- Section index: build/<section>/index.html
  "build/*/index.html" %> \out -> do
    let section = takeBaseName (takeDirectory out)
    if section `elem` map T.unpack (map sectionLabel allSections)
      then do
        hs <- getDirectoryFiles "" ["app//*.hs", "src//*.hs"]
        need hs
        need ["gfx/gfx.js", "css/style.css"]
        buildSection (T.pack section)
      else if section == "about"
        then buildAbout
        else liftIO (putStrLn ("skip " ++ out))

  "build/index.html" %> \_ -> do
    hs <- getDirectoryFiles "" ["app//*.hs", "src//*.hs"]
    need hs
    need ["gfx/gfx.js", "css/style.css"]
    buildHome

  "build/css/style.css" %> \out -> do
    need [ "tailwind.config.js", "package.json", "css/style.css" ]
    hsFiles <- getDirectoryFiles "" ["app//*.hs", "src//*.hs"]
    need hsFiles
    command [Cwd "."] "npx" ["tailwindcss", "-i", "css/style.css", "-o", out]

  "build/_headers" %> \out -> do
    need ["public/_headers"]
    copyFile' "public/_headers" out

  "build/gfx.js" %> \out -> do
    need ["gfx/gfx.js"]
    copyFile' "gfx/gfx.js" out

  "build/spa.js" %> \out -> do
    need ["js/spa.js"]
    copyFile' "js/spa.js" out

  "build/theme.js" %> \out -> do
    need ["js/theme.js"]
    copyFile' "js/theme.js" out

  "build/cover.js" %> \out -> do
    need ["js/cover.js"]
    copyFile' "js/cover.js" out

  -- Mirror public/assets/** into build/assets/**
  "build/assets//**" %> \out -> mirrorPublic "assets" out

  -- Mirror public/fonts/** into build/fonts/**
  "build/fonts//**" %> \out -> mirrorPublic "fonts" out

mirrorPublic :: String -> FilePath -> Action ()
mirrorPublic prefix out = do
  let rel = makeRelative ("build" </> prefix) out
      src = "public" </> prefix </> rel
  need [src]
  copyFile' src out

parsePort :: [String] -> Int
parsePort args = go args 8000
  where
    go []                              d = d
    go ("--port":n:xs)                 d = go xs (readInt n d)
    go (a:xs) d
      | Just n <- stripPrefix "--port=" a = go xs (readInt n d)
    go (_:xs) d                        = go xs d
    readInt s d = case readMaybe s of Just n -> n; Nothing -> d

main :: IO ()
main = do
  args <- getArgs
  if "serve" `elem` args
    then Dev.devServer (parsePort args) "build" ["site", "css", "js", "gfx", "public"] shakeOptions buildRules
    else shakeArgs shakeOptions buildRules
