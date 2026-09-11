-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The prose vocabulary: the structured body of a markdown post, and the
-- pure renderer that turns it into Miso nodes.
--
-- Markdown is parsed once, at build time, by @scripts/content/generate.mjs@,
-- which emits 'Block' values in @Site.Content.Generated@. Nothing here parses
-- anything: the native prerenderer and the browser render the same data with
-- the same code, so there is no HTML string and no injection step.
--
-- The element and class choices mirror the DOM the old markdown-it pipeline
-- produced, including heading anchors, the footnote section, the
-- highlight.js token spans, and the dithered-image markup.
module Site.Prose
  ( -- * Blocks
    Block (..)
  , Footnote (..)
    -- * Inlines
  , Inline (..)
    -- * Rendering
  , renderBlocks
  , renderInlines
  ) where
-----------------------------------------------------------------------------
import           Miso (View, text)
import qualified Miso.Html.Element as H
import qualified Miso.Html.Property as P
import           Miso.Property (textProp)
import           Miso.String (MisoString, ms)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
-----------------------------------------------------------------------------
data Block
  = Paragraph [Inline]
  -- ^ A loose paragraph.
  | Plain [Inline]
  -- ^ The contents of a tight list item: no @\<p\>@ wrapper.
  | Heading Int MisoString [Inline]
  -- ^ Level, anchor id (empty when the heading gets none), content.
  | CodeBlock (Maybe MisoString) [Inline]
  -- ^ Language and already-highlighted content. 'Nothing' means no language.
  | BulletList [[Block]]
  | OrderedList [[Block]]
  | BlockQuote [Block]
  |   Table [[[Inline]]] [[[Inline]]]
  -- ^ Header and body rows; each row is a list of cells, each cell inlines.
  | Rule
  | Footnotes [Footnote]
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data Footnote = Footnote
  { footnoteNumber :: Int
  , footnoteRefs   :: [MisoString]
  -- ^ Ids of the references in the text, in reading order, so every one can
  -- be linked back to.
  , footnoteBlocks :: [Block]
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data Inline
  = Text MisoString
  | Emphasis [Inline]
  | Strong [Inline]
  | Code MisoString
  | Link MisoString (Maybe MisoString) [Inline]
  -- ^ Href, title, label.
  | Image MisoString MisoString (Maybe MisoString)
  -- ^ A dithered image: source, alt, title.
  | PlainImage MisoString MisoString (Maybe MisoString)
  -- ^ A GIF or a @#no-dither@ image: source, alt, title.
  | Video MisoString MisoString (Maybe MisoString)
  -- ^ An MP4: source, alt, title.
  | SoftBreak
  | HardBreak
  | FootnoteRef Int MisoString
  -- ^ Footnote number and the id of this reference.
  | Span MisoString [Inline]
  -- ^ A classed span, used for highlight.js tokens.
  deriving (Show, Eq)
-----------------------------------------------------------------------------
type Node context model action = View context model action
-----------------------------------------------------------------------------
renderBlocks :: [Block] -> [Node context model action]
renderBlocks = concatMap renderBlock
-----------------------------------------------------------------------------
renderInlines :: [Inline] -> [Node context model action]
renderInlines = concatMap renderInline
-----------------------------------------------------------------------------
renderBlock :: Block -> [Node context model action]
renderBlock = \case
  Paragraph inlines -> [H.p_ [] (renderInlines inlines)]
  Plain inlines -> renderInlines inlines
  Heading level anchor inlines ->
    [ headingElement level (anchorAttributes anchor) (renderInlines inlines) ]
  CodeBlock language inlines ->
    [ H.pre_
        []
        [ H.code_ [ P.class_ (codeClass language) ] (renderInlines inlines) ]
    ]
  BulletList items -> [H.ul_ [] (map renderItem items)]
  OrderedList items -> [H.ol_ [] (map renderItem items)]
  BlockQuote blocks -> [H.blockquote_ [] (renderBlocks blocks)]
  Table headerRows bodyRows ->
    [ H.table_
        []
        [ H.thead_ [] [ renderRow H.th_ row | row <- headerRows ]
        , H.tbody_ [] [ renderRow H.td_ row | row <- bodyRows ]
        ]
    ]
  Rule -> [H.hr_ []]
  Footnotes footnotes -> renderFootnotes footnotes
  where
    renderItem blocks = H.li_ [] (renderBlocks blocks)
    renderRow cell cells = H.tr_ [] [ cell [] (renderInlines inlines) | inlines <- cells ]
    headingElement level
      | level <= 2 = H.h2_
      | level == 3 = H.h3_
      | level == 4 = H.h4_
      | level == 5 = H.h5_
      | otherwise  = H.h6_
    anchorAttributes "" = []
    anchorAttributes anchor = [ P.id_ anchor, textProp "tabindex" "-1" ]
    codeClass Nothing = "hljs"
    codeClass (Just language) = "hljs language-" <> language
-----------------------------------------------------------------------------
-- | The footnote section markdown-it-footnote produced: a separator, then an
-- ordered list whose items carry a back-reference to the reference.
renderFootnotes :: [Footnote] -> [Node context model action]
renderFootnotes [] = []
renderFootnotes footnotes =
  [ H.hr_ [ P.class_ "footnotes-sep" ]
  , H.section_ [ P.class_ "footnotes" ]
      [ H.ol_ [ P.class_ "footnotes-list" ]
          [ H.li_
              [ P.id_ ("fn" <> numberOf footnote)
              , P.class_ "footnote-item"
              ]
              (footnoteContent footnote)
          | footnote <- footnotes
          ]
      ]
  ]
  where
    numberOf = ms . show . footnoteNumber
    backReference refId =
      H.a_
        [ P.href_ ("#" <> refId)
        , P.class_ "footnote-backref"
        ]
        [ text "↩︎" ]
    footnoteContent footnote =
      let anchors = map backReference (footnoteRefs footnote)
      in case reverse (footnoteBlocks footnote) of
        (Paragraph inlines : rest) ->
          renderBlocks (reverse rest)
            <> [ H.p_ [] (renderInlines inlines <> [text " "] <> anchors) ]
        _ -> renderBlocks (footnoteBlocks footnote) <> anchors
-----------------------------------------------------------------------------
renderInline :: Inline -> [Node context model action]
renderInline = \case
  Text contents -> [text contents]
  Emphasis inlines -> [H.em_ [] (renderInlines inlines)]
  Strong inlines -> [H.strong_ [] (renderInlines inlines)]
  Code contents -> [H.code_ [] [text contents]]
  Link href title inlines ->
    [ H.a_ (hrefAttribute href <> titleAttribute title) (renderInlines inlines) ]
  Image source alt title ->
    [ H.span_
        [ P.class_ "dithered-image dithered-image-inline"
        , P.data_ Config.ditheredImageKey ""
        ]
        [ H.img_
            ( [ P.class_ "dithered-image-source"
              , P.data_ Config.ditheredSourceKey ""
              , P.src_ source
              , textProp "alt" alt
              , textProp "loading" "lazy"
              ]
              <> titleAttribute title
            )
        , H.canvas_
            [ P.data_ Config.ditheredCanvasKey ""
            , P.aria_ "hidden" "true"
            ]
            []
        ]
    ]
  PlainImage source alt title ->
    [ H.img_
        ( [ P.class_ "markdown-image-plain"
          , P.src_ source
          , textProp "alt" alt
          , textProp "loading" "lazy"
          ]
          <> titleAttribute title
        )
    ]
  Video source alt title ->
    [ H.video_
        ( [ P.class_ "markdown-video-plain"
          , P.src_ source
          , P.controls_ True
          , textProp "playsinline" ""
          , P.preload_ "metadata"
          , textProp "aria-label" alt
          ]
          <> titleAttribute title
        )
        []
    ]
  SoftBreak -> ["\n"]
  HardBreak -> [H.br_ []]
  FootnoteRef n refId ->
    [ H.sup_ [ P.class_ "footnote-ref" ]
        [ H.a_
            [ P.href_ ("#fn" <> number)
            , P.id_ refId
            ]
            [ text ("[" <> number <> "]") ]
        ]
    ]
    where
      number = ms (show n)
  Span className inlines ->
    [ H.span_ [ P.class_ className ] (renderInlines inlines) ]
  where
    hrefAttribute href = [ P.href_ href ]
    titleAttribute = \case
      Nothing -> []
      Just value -> [ textProp "title" value ]
