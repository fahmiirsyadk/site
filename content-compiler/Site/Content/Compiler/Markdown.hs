{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Site.Content.Compiler.Markdown
  ( ParsedDocument (..)
  , Toc (..)
  , parseMarkdown
  ) where

import Control.Monad.State.Strict (State, evalState, get, modify)
import Data.Char (isDigit, toLower)
import Data.List (isSuffixOf)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Functor.Identity (Identity (..))
import Commonmark.Parser (commonmarkWith)
import Commonmark.Syntax (defaultSyntaxSpec)
import qualified Commonmark.Types as CM
import Commonmark.Types
  ( Format
  , HasAttributes (..)
  , IsBlock (..)
  , IsInline (..)
  , Rangeable (..)
  )
import Commonmark.Extensions.Footnote
  ( HasFootnote (..)
  , footnoteSpec
  )
import Commonmark.Extensions.Autolink (autolinkSpec)
import Commonmark.Extensions.PipeTable
  ( ColAlignment (..)
  , HasPipeTable (..)
  , pipeTableSpec
  )
import Commonmark.Extensions.Smart (HasQuoted (..), smartPunctuationSpec)
import Site.Prose.Types
  ( Block (..)
  , ColumnAlignment (..)
  , Footnote (..)
  , Inline (..)
  )

data ParsedDocument = ParsedDocument
  { parsedBlocks :: [Block]
  , parsedToc :: [Toc]
  } deriving (Show, Eq)

data Toc = Toc
  { tocId :: Text
  , tocLabel :: Text
  , tocLevel :: Int
  } deriving (Show, Eq)

data RawInline
  = RawText Text
  | RawEmphasis InlineFrag
  | RawStrong InlineFrag
  | RawCode Text
  | RawLink Text Text InlineFrag
  | RawImage Text Text InlineFrag
  | RawSoftBreak
  | RawLineBreak
  | RawFootnoteRef Text Text
  | RawInlineHtml Format Text
  deriving (Show, Eq)

newtype InlineFrag = InlineFrag [RawInline]
  deriving (Show, Eq)

data RawBlock
  = RawParagraph InlineFrag
  | RawPlain InlineFrag
  | RawHeading Int InlineFrag
  | RawCodeBlock Text Text
  | RawBulletList [BlockFrag]
  | RawOrderedList Int [BlockFrag]
  | RawBlockQuote BlockFrag
  | RawTable [ColumnAlignment] [InlineFrag] [[InlineFrag]]
  | RawRule
  | RawFootnote Int Text BlockFrag
  | RawFootnoteList [BlockFrag]
  | RawBlockHtml Format Text
  | RawReference Text (Text, Text)
  deriving (Show, Eq)

newtype BlockFrag = BlockFrag [RawBlock]
  deriving (Show, Eq)

instance Semigroup InlineFrag where
  InlineFrag left <> InlineFrag right = InlineFrag (left <> right)

instance Monoid InlineFrag where
  mempty = InlineFrag []

instance Rangeable InlineFrag where
  ranged _ = id

instance HasAttributes InlineFrag where
  addAttributes _ = id

instance IsInline InlineFrag where
  lineBreak = InlineFrag [RawLineBreak]
  softBreak = InlineFrag [RawSoftBreak]
  str = InlineFrag . pure . RawText
  entity = InlineFrag . pure . RawText
  escapedChar = str . T.singleton
  emph = InlineFrag . pure . RawEmphasis
  strong = InlineFrag . pure . RawStrong
  link href title label = InlineFrag [RawLink href title label]
  image source title alt = InlineFrag [RawImage source title alt]
  code = InlineFrag . pure . RawCode
  rawInline format contents = InlineFrag [RawInlineHtml format contents]

instance HasQuoted InlineFrag where
  singleQuoted contents = InlineFrag [RawText "‘"] <> contents <> InlineFrag [RawText "’"]
  doubleQuoted contents = InlineFrag [RawText "“"] <> contents <> InlineFrag [RawText "”"]

instance Semigroup BlockFrag where
  BlockFrag left <> BlockFrag right = BlockFrag (left <> right)

instance Monoid BlockFrag where
  mempty = BlockFrag []

instance Rangeable BlockFrag where
  ranged _ = id

instance HasAttributes BlockFrag where
  addAttributes _ = id

instance IsBlock InlineFrag BlockFrag where
  paragraph = BlockFrag . pure . RawParagraph
  plain = BlockFrag . pure . RawPlain
  thematicBreak = BlockFrag [RawRule]
  blockQuote = BlockFrag . pure . RawBlockQuote
  codeBlock info contents = BlockFrag [RawCodeBlock info contents]
  heading level = BlockFrag . pure . RawHeading level
  rawBlock format contents = BlockFrag [RawBlockHtml format contents]
  referenceLinkDefinition label target = BlockFrag [RawReference label target]
  list listType spacing items = BlockFrag [listBlock listType spacing items]

instance HasPipeTable InlineFrag BlockFrag where
  pipeTable alignments header body = BlockFrag
    [ RawTable (map convertAlignment alignments) header body ]
    where
      convertAlignment LeftAlignedCol = AlignLeft
      convertAlignment CenterAlignedCol = AlignCenter
      convertAlignment RightAlignedCol = AlignRight
      convertAlignment DefaultAlignedCol = AlignDefault

instance HasFootnote InlineFrag BlockFrag where
  footnote number label body = BlockFrag [RawFootnote number label body]
  footnoteList = BlockFrag . pure . RawFootnoteList
  footnoteRef number label _ = InlineFrag [RawFootnoteRef number label]

listBlock :: CM.ListType -> CM.ListSpacing -> [BlockFrag] -> RawBlock
listBlock listType _ items = case listType of
  CM.BulletList _ -> RawBulletList items
  CM.OrderedList start _ _ -> RawOrderedList start items

data NormalizeState = NormalizeState
  { headingCounts :: [(Text, Int)]
  , referenceIds :: [(Int, [Text])]
  }

parseMarkdown :: FilePath -> Text -> Either String ParsedDocument
parseMarkdown sourceName source =
  case runIdentity (commonmarkWith syntax sourceName source) of
    Left parseError -> Left (show parseError)
    Right (BlockFrag blocks) ->
      case unsupportedBlock blocks of
        Just errorMessage -> Left (sourceName <> ": " <> errorMessage)
        Nothing ->
          let (normalized, _state) = normalizeBlocks blocks `runWith` NormalizeState [] []
              toc = collectToc normalized
          in Right (ParsedDocument normalized toc)
  where
    syntax = defaultSyntaxSpec <> pipeTableSpec <> footnoteSpec <> smartPunctuationSpec <> autolinkSpec

unsupportedBlock :: [RawBlock] -> Maybe String
unsupportedBlock = firstJust . map unsupportedRawBlock
  where
    unsupportedRawBlock raw = case raw of
      RawParagraph inlines -> unsupportedInline inlines
      RawPlain inlines -> unsupportedInline inlines
      RawHeading _ inlines -> unsupportedInline inlines
      RawBulletList items -> unsupportedBlock (concatMap blockFragBlocks items)
      RawOrderedList _ items -> unsupportedBlock (concatMap blockFragBlocks items)
      RawBlockQuote blocks -> unsupportedBlock (blockFragBlocks blocks)
      RawTable _ header body -> firstJust (map unsupportedInline header <> map (firstJust . map unsupportedInline) body)
      RawFootnote _ _ body -> unsupportedBlock (blockFragBlocks body)
      RawFootnoteList items -> unsupportedBlock (concatMap blockFragBlocks items)
      RawBlockHtml _ _ -> Just "raw HTML blocks are not supported"
      RawReference label _ -> Just ("reference link definitions are not supported: " <> T.unpack label)
      _ -> Nothing
    blockFragBlocks (BlockFrag blocks) = blocks
    unsupportedInline (InlineFrag inlines) = firstJust (map unsupportedRawInline inlines)
    unsupportedRawInline raw = case raw of
      RawEmphasis inlines -> unsupportedInline inlines
      RawStrong inlines -> unsupportedInline inlines
      RawLink _ _ label -> unsupportedInline label
      RawImage _ _ alt -> unsupportedInline alt
      RawInlineHtml _ _ -> Just "raw HTML inlines are not supported"
      _ -> Nothing
    firstJust [] = Nothing
    firstJust (value : rest) = case value of
      Just _ -> value
      Nothing -> firstJust rest

runWith :: State s a -> s -> (a, s)
runWith action state =
  let result = evalState ((,) <$> action <*> get) state
  in result

normalizeBlocks :: [RawBlock] -> State NormalizeState [Block]
normalizeBlocks = fmap concat . mapM normalizeBlock

normalizeBlock :: RawBlock -> State NormalizeState [Block]
normalizeBlock raw = case raw of
  RawParagraph inlines -> Paragraph <$> normalizeInlines inlines >>= pure . pure
  RawPlain inlines -> Plain <$> normalizeInlines inlines >>= pure . pure
  RawHeading level inlines -> do
    contents <- normalizeInlines inlines
    let label = plainText contents
    anchor <- if level >= 2 && level <= 4 then freshHeading label else pure ""
    pure [Heading level anchor contents]
  RawCodeBlock info contents ->
    pure [CodeBlock (emptyToNothing info) [Text contents]]
  RawBulletList items -> do
    normalized <- mapM normalizeBlocksFromFrag items
    pure [BulletList normalized]
  RawOrderedList start items -> do
    normalized <- mapM normalizeBlocksFromFrag items
    pure [OrderedList start normalized]
  RawBlockQuote blocks -> do
    normalized <- normalizeBlocksFromFrag blocks
    pure [BlockQuote normalized]
  RawTable alignments header body ->
    Table alignments <$> (pure <$> mapM normalizeInlines header)
      <*> mapM (mapM normalizeInlines) body
      >>= pure . pure
  RawRule -> pure [Rule]
  RawFootnoteList items -> do
    normalized <- mapM normalizeFootnote items
    pure [Footnotes normalized]
  RawFootnote number label body -> do
    normalized <- normalizeFootnote (BlockFrag [RawFootnote number label body])
    pure [Footnotes [normalized]]
  RawBlockHtml format contents ->
    pure (errorBlock ("raw HTML block is not supported: " <> show format <> " " <> T.unpack contents))
  RawReference label target ->
    pure (errorBlock ("reference link definitions are not supported: " <> T.unpack label <> " " <> show target))

normalizeBlocksFromFrag :: BlockFrag -> State NormalizeState [Block]
normalizeBlocksFromFrag (BlockFrag blocks) = normalizeBlocks blocks

normalizeFootnote :: BlockFrag -> State NormalizeState Footnote
normalizeFootnote (BlockFrag [RawFootnote number _ body]) = do
  blocks <- normalizeBlocksFromFrag body
  refs <- lookupRefs number
  pure (Footnote number refs blocks)
normalizeFootnote (BlockFrag blocks) = do
  normalized <- normalizeBlocks blocks
  pure (Footnote 0 [] normalized)

normalizeInlines :: InlineFrag -> State NormalizeState [Inline]
normalizeInlines (InlineFrag inlines) = concat <$> mapM normalizeInline inlines

normalizeInline :: RawInline -> State NormalizeState [Inline]
normalizeInline raw = case raw of
  RawText contents -> pure [Text contents]
  RawEmphasis contents -> pure . pure . Emphasis =<< normalizeInlines contents
  RawStrong contents -> pure . pure . Strong =<< normalizeInlines contents
  RawCode contents -> pure [Code contents]
  RawLink href title label -> pure . pure . Link href (emptyToNothing title) =<< normalizeInlines label
  RawImage source title alt -> do
    normalized <- normalizeInlines alt
    pure [classifyImage source (emptyToNothing title) (plainText normalized)]
  RawSoftBreak -> pure [SoftBreak]
  RawLineBreak -> pure [HardBreak]
  RawFootnoteRef number _label -> do
    let number' = readNumber number
    state <- get
    let refs = lookupCountList number' (referenceIds state)
        refId = "fnref" <> T.pack (show number') <> if null refs then "" else ":" <> T.pack (show (length refs + 1))
    modify (\current -> current { referenceIds = addReference number' refId (referenceIds current) })
    pure [FootnoteRef number' refId]
  RawInlineHtml format contents -> pure (errorInline ("raw HTML inline is not supported: " <> show format <> " " <> T.unpack contents))
  where
    lookupCountList key values = maybe [] id (lookup key values)
    addReference key ref [] = [(key, [ref])]
    addReference key ref ((current, refs) : rest)
      | key == current = (current, refs <> [ref]) : rest
      | otherwise = (current, refs) : addReference key ref rest

classifyImage :: Text -> Maybe Text -> Text -> Inline
classifyImage rawSource title alt
  | "#no-dither" `T.isSuffixOf` rawSource = PlainImage source alt title
  | ".mp4" `isSuffixOf` mediaPath source = Video source alt title
  | ".gif" `isSuffixOf` mediaPath source = PlainImage source alt title
  | otherwise = Image source alt title
  where
    source
      | "#no-dither" `T.isSuffixOf` rawSource = T.dropEnd (T.length "#no-dither") rawSource
      | otherwise = rawSource

mediaPath :: Text -> String
mediaPath = map toLower . T.unpack . T.takeWhile (not . (`elem` ['?', '#']))

emptyToNothing :: Text -> Maybe Text
emptyToNothing value = if T.null value then Nothing else Just value

plainText :: [Inline] -> Text
plainText = T.concat . map inlineText
  where
    inlineText (Text value) = value
    inlineText (Code value) = value
    inlineText (Emphasis values) = plainText values
    inlineText (Strong values) = plainText values
    inlineText (Link _ _ values) = plainText values
    inlineText (Span _ values) = plainText values
    inlineText _ = ""

freshHeading :: Text -> State NormalizeState Text
freshHeading label = do
  state <- get
  let base = slugify label
      seen = lookupCount base (headingCounts state)
      anchor = if seen == 0 then base else base <> "-" <> T.pack (show (seen + 1))
  modify (\current -> current { headingCounts = setCount base (seen + 1) (headingCounts current) })
  pure anchor

lookupCount :: Eq a => a -> [(a, Int)] -> Int
lookupCount key values = maybe 0 id (lookup key values)

setCount :: Eq a => a -> Int -> [(a, Int)] -> [(a, Int)]
setCount key value [] = [(key, value)]
setCount key value ((current, currentValue) : rest)
  | key == current = (key, value) : rest
  | otherwise = (current, currentValue) : setCount key value rest

lookupRefs :: Int -> State NormalizeState [Text]
lookupRefs number = do
  state <- get
  pure (maybe ["fnref" <> T.pack (show number)] id (lookup number (referenceIds state)))

readNumber :: Text -> Int
readNumber value = case reads (T.unpack value) of
  [(number, "")] -> number
  _ -> 0

slugify :: Text -> Text
slugify = T.dropAround (== '-') . collapse . T.map normalize . T.toLower
  where
    normalize character
      | isDigit character || character >= 'a' && character <= 'z' = character
      | otherwise = '-'
    collapse value = T.intercalate "-" (filter (not . T.null) (T.split (== '-') value))

collectToc :: [Block] -> [Toc]
collectToc = concatMap tocBlock
  where
    tocBlock (Heading level anchor inlines)
      | T.null anchor = []
      | otherwise = [Toc anchor (plainText inlines) level]
    tocBlock (BulletList items) = concatMap collectToc items
    tocBlock (OrderedList _ items) = concatMap collectToc items
    tocBlock (BlockQuote blocks) = collectToc blocks
    tocBlock (Footnotes notes) = concatMap (collectToc . footnoteBlocks) notes
    tocBlock _ = []

errorBlock :: String -> [Block]
errorBlock message = error message

errorInline :: String -> [Inline]
errorInline message = error message
