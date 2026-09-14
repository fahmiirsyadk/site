{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import qualified Data.Text as T
import Site.Content.Compiler.Frontmatter (compilePost)
import Site.Content.Compiler.Highlight (highlightPosts)
import Site.Content.Types (Post (..), TocEntry (..))
import Site.Prose.Types (Block (..), ColumnAlignment (..), Footnote (..), Inline (..))

main :: IO ()
main = do
  post <- case compilePost "fixture.md" fixture of
    Left errorMessage -> fail errorMessage
    Right value -> pure value
  check "titled link and image" (hasTitledMedia (postBody post))
  check "ordered-list start" (hasBlock matchesOrdered (postBody post))
  check "table alignment" (hasBlock matchesTable (postBody post))
  check "heading collision" (map tocId (postToc post) == ["same", "same-2"])
  check "raw HTML rejection" (case compilePost "raw.md" (frontmatter <> "<span>raw</span>") of
    Left _ -> True
    Right _ -> False)
  check "invalid date rejection" (case compilePost "date.md" (replaceDate fixture) of
    Left _ -> True
    Right _ -> False)
  highlighted <- highlightPosts (postBody post)
  case highlighted of
    Left errorMessage -> fail errorMessage
    Right body -> check "highlighted spans" (hasSpan body)
  putStrLn "compiler checks passed"
  where
    matchesOrdered (OrderedList 3 _) = True
    matchesOrdered _ = False
    matchesTable (Table [AlignLeft, AlignCenter, AlignRight] _ _) = True
    matchesTable _ = False

check :: String -> Bool -> IO ()
check label condition = unless condition (fail (label <> " failed"))

hasBlock :: (Block -> Bool) -> [Block] -> Bool
hasBlock predicate = any (\block -> predicate block || nested block)
  where
    nested (BulletList items) = any (hasBlock predicate) items
    nested (OrderedList _ items) = any (hasBlock predicate) items
    nested (BlockQuote blocks) = hasBlock predicate blocks
    nested (Footnotes notes) = any (hasBlock predicate . footnoteBlocks) notes
    nested _ = False

hasTitledMedia :: [Block] -> Bool
hasTitledMedia = any (hasInline . blockInlines)
  where
    hasInline = any $ \case
      Link _ (Just "link title") _ -> True
      Image _ _ (Just "image title") -> True
      PlainImage _ _ (Just "gif title") -> True
      _ -> False
    blockInlines (Paragraph inlines) = inlines
    blockInlines (Plain inlines) = inlines
    blockInlines (Heading _ _ inlines) = inlines
    blockInlines _ = []

hasSpan :: [Block] -> Bool
hasSpan = any (anyInline . blockInlines)
  where
    anyInline = any $ \case
      Span _ _ -> True
      Emphasis values -> anyInline values
      Strong values -> anyInline values
      Link _ _ values -> anyInline values
      _ -> False
    blockInlines (Paragraph inlines) = inlines
    blockInlines (Plain inlines) = inlines
    blockInlines (Heading _ _ inlines) = inlines
    blockInlines (CodeBlock _ inlines) = inlines
    blockInlines _ = []

frontmatter :: T.Text
frontmatter = "---\n"
  <> "title: Fixture\n"
  <> "date: \"2026-09-14T12:00:00+00:00\"\n"
  <> "slug: fixture\n"
  <> "section: lab\n"
  <> "status: published\n"
  <> "tags: [fixture]\n"
  <> "---\n"

fixture :: T.Text
fixture = frontmatter
  <> "## Same\n\n"
  <> "## Same\n\n"
  <> "[link](https://example.com \"link title\") ![image](/image.png \"image title\") ![gif](/image.gif \"gif title\")\n\n"
  <> "3. starts later\n\n"
  <> "| Left | Center | Right |\n| :--- | :---: | ---: |\n| one | two | three |\n\n"
  <> "```javascript\nconst answer = 42\n```\n"

replaceDate :: T.Text -> T.Text
replaceDate = T.replace "2026-09-14" "not-a-date"
