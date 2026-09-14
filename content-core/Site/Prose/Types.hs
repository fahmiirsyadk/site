{-# LANGUAGE OverloadedStrings #-}

-- | The build-time content vocabulary shared by the compiler and application.
module Site.Prose.Types
  ( Block (..)
  , ColumnAlignment (..)
  , Footnote (..)
  , Inline (..)
  ) where

import Data.Text (Text)

data Block
  = Paragraph [Inline]
  | Plain [Inline]
  | Heading Int Text [Inline]
  | CodeBlock (Maybe Text) [Inline]
  | BulletList [[Block]]
  | OrderedList Int [[Block]]
  | BlockQuote [Block]
  | Table [ColumnAlignment] [[[Inline]]] [[[Inline]]]
  | Rule
  | Footnotes [Footnote]
  deriving (Show, Eq)

data ColumnAlignment
  = AlignLeft
  | AlignCenter
  | AlignRight
  | AlignDefault
  deriving (Show, Eq)

data Footnote = Footnote
  { footnoteNumber :: Int
  , footnoteRefs :: [Text]
  , footnoteBlocks :: [Block]
  } deriving (Show, Eq)

data Inline
  = Text Text
  | Emphasis [Inline]
  | Strong [Inline]
  | Code Text
  | Link Text (Maybe Text) [Inline]
  | Image Text Text (Maybe Text)
  | PlainImage Text Text (Maybe Text)
  | Video Text Text (Maybe Text)
  | SoftBreak
  | HardBreak
  | FootnoteRef Int Text
  | Span Text [Inline]
  deriving (Show, Eq)
