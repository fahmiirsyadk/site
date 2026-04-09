module BuildContentMain where

import Prelude

import BuildContent.Discover (discoverMarkdownFiles)
import BuildContent.MarkdownDoc (ParsedDocument, parseMarkdownDocument)
import Data.Argonaut.Encode (encodeJson, toJsonString)
import Data.Array as Array
import Data.Maybe (fromMaybe)
import Data.String as String
import Effect (Effect)
import Effect.Console (log)
import Node.Encoding as Enc
import Node.FS.Sync as FS
import Node.Path (concat) as Path
import Node.Process (cwd)
import Sections (extraTagsForSection, isThoughtSection)
import Types (Post, SiteManifest, Thought)

byDateDesc :: forall a. { date :: String | a } -> { date :: String | a } -> Ordering
byDateDesc a b = compare b.date a.date

mkPost :: String -> String -> ParsedDocument -> Post
mkPost section baseName parsed =
  let
    slugFromFm = fromMaybe "" parsed.fields.slug
    slug = if String.length slugFromFm > 0 then slugFromFm else baseName
    baseTags = fromMaybe [] parsed.fields.tags
    extra = extraTagsForSection section
    tags = Array.nub (baseTags <> extra)
    title = fromMaybe slug parsed.fields.title
  in
    { slug
    , title: if String.length title > 0 then title else slug
    , date: parsed.dateIso
    , description: fromMaybe "" parsed.fields.description
    , bodyHtml: parsed.rendered.bodyHtml
    , toc: parsed.rendered.toc
    , section
    , tags
    , excerpt: fromMaybe "" parsed.fields.excerpt
    }

mkThought :: String -> ParsedDocument -> Thought
mkThought baseName parsed =
  let
    slugFromFm = fromMaybe "" parsed.fields.slug
    slug = if String.length slugFromFm > 0 then slugFromFm else baseName
    title = fromMaybe "Note" parsed.fields.title
  in
    { slug
    , title: if String.length title > 0 then title else "Note"
    , date: parsed.dateIso
    , status: fromMaybe "" parsed.fields.status
    , pinned: fromMaybe false parsed.fields.pinned
    , bodyHtml: parsed.rendered.bodyHtml
    , excerpt: fromMaybe "" parsed.fields.excerpt
    }

main :: Effect Unit
main = do
  files <- discoverMarkdownFiles
  let
    sectioned = Array.filter (\f -> String.length f.section > 0) files

  let
    step acc f = do
      raw <- FS.readTextFile Enc.UTF8 f.filePath
      parsed <- parseMarkdownDocument raw
      let
        status = fromMaybe "published" parsed.fields.status
      if status /= "published" then
        pure acc
      else if isThoughtSection f.section then
        pure acc { thoughts = acc.thoughts <> [ mkThought f.baseName parsed ] }
      else
        pure acc { posts = acc.posts <> [ mkPost f.section f.baseName parsed ] }

  initAcc <- pure { posts: [] :: Array Post, thoughts: [] :: Array Thought }
  acc <- Array.foldM step initAcc sectioned

  let
    postsSorted = Array.sortBy byDateDesc acc.posts
    thoughtsSorted = Array.sortBy
      (\a b ->
        if a.pinned /= b.pinned then compare b.pinned a.pinned else byDateDesc a b
      )
      acc.thoughts

    tags = Array.sort (Array.nub (Array.concatMap _.tags postsSorted))
    manifest :: SiteManifest
    manifest = { posts: postsSorted, thoughts: thoughtsSorted, tags }

  root <- cwd
  let outPath = Path.concat [ root, "generated/posts.json" ]
  FS.writeTextFile Enc.UTF8 outPath (toJsonString (encodeJson manifest) <> "\n")
  log $ "Wrote " <> outPath
