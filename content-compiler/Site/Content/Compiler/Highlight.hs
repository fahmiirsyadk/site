{-# LANGUAGE OverloadedStrings #-}

module Site.Content.Compiler.Highlight
  ( highlightPosts
  ) where

import Control.Monad.State.Strict (State, evalState, state)
import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , encode
  , eitherDecode
  , object
  , withObject
  , (.:)
  , (.=)
  )
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Text (Text)
import qualified Data.Text as T
import Site.Prose.Types (Block (..), Footnote (..), Inline (..))
import System.Exit (ExitCode (..))
import System.Process (readProcessWithExitCode)

data Request = Request
  { requestId :: Int
  , requestCode :: Text
  , requestLanguage :: Text
  }

instance ToJSON Request where
  toJSON request = object
    [ "id" .= requestId request
    , "code" .= requestCode request
    , "language" .= requestLanguage request
    ]

data Node = NodeText Text | NodeSpan Text [Node]

instance FromJSON Node where
  parseJSON = withObject "highlight node" $ \value -> do
    kind <- value .: "kind"
    case (kind :: Text) of
      "text" -> NodeText <$> value .: "value"
      "span" -> NodeSpan <$> value .: "className" <*> value .: "children"
      other -> fail ("unknown highlight node kind: " <> T.unpack other)

data Response = Response
  { responseId :: Int
  , responseNodes :: [Node]
  }

instance FromJSON Response where
  parseJSON = withObject "highlight response" $ \value ->
    Response <$> value .: "id" <*> value .: "nodes"

highlightPosts :: [Block] -> IO (Either String [Block])
highlightPosts blocks = do
  let requests = collectRequests blocks
  if null requests
    then pure (Right blocks)
    else do
      (exitCode, stdout, stderr) <- readProcessWithExitCode "node" ["scripts/content/highlight.mjs"]
        (BL.unpack (encode requests))
      case exitCode of
        ExitFailure _ -> pure (Left ("highlight.js adapter failed: " <> stderr))
        ExitSuccess -> case eitherDecode (BL.pack stdout) of
          Left errorMessage -> pure (Left ("invalid highlight.js response: " <> errorMessage))
          Right responses
            | map responseId responses /= map requestId requests ->
                pure (Left "highlight.js response ids do not match requests")
            | not (and (zipWith preserves requests responses)) ->
                pure (Left "highlight.js changed code-block text")
            | otherwise -> pure (Right (applyResponses responses blocks))

collectRequests :: [Block] -> [Request]
collectRequests blocks = snd (collect 0 blocks)
  where
    collect next [] = (next, [])
    collect next (block : rest) = case block of
      CodeBlock language inlines ->
        let (after, remaining) = collect (next + 1) rest
        in (after, Request next (inlineText inlines) (maybe "" id language) : remaining)
      BulletList items ->
        let (afterItems, itemRequests) = collectItems next items
            (afterRest, restRequests) = collect afterItems rest
        in (afterRest, itemRequests <> restRequests)
      OrderedList _ items ->
        let (afterItems, itemRequests) = collectItems next items
            (afterRest, restRequests) = collect afterItems rest
        in (afterRest, itemRequests <> restRequests)
      BlockQuote nested ->
        let (afterNested, nestedRequests) = collect next nested
            (afterRest, restRequests) = collect afterNested rest
        in (afterRest, nestedRequests <> restRequests)
      Footnotes notes ->
        let (afterNotes, noteRequests) = collectItems next (map footnoteBlocks notes)
            (afterRest, restRequests) = collect afterNotes rest
        in (afterRest, noteRequests <> restRequests)
      _ -> collect next rest
    collectItems next [] = (next, [])
    collectItems next (items : rest) =
      let (afterItems, itemRequests) = collect next items
          (afterRest, restRequests) = collectItems afterItems rest
      in (afterRest, itemRequests <> restRequests)

inlineText :: [Inline] -> Text
inlineText = T.concat . map textOf
  where
    textOf (Text value) = value
    textOf (Span _ values) = inlineText values
    textOf _ = ""

preserves :: Request -> Response -> Bool
preserves request response = requestCode request == leaves (responseNodes response)

leaves :: [Node] -> Text
leaves = T.concat . map nodeText

nodeText :: Node -> Text
nodeText (NodeText value) = value
nodeText (NodeSpan _ children) = leaves children

applyResponses :: [Response] -> [Block] -> [Block]
applyResponses responses blocks = evalState (mapM applyBlock blocks) responses
  where
    applyBlock :: Block -> State [Response] Block
    applyBlock block = case block of
      CodeBlock language _ -> do
        response <- state (\remaining -> case remaining of
          (current : rest) -> (current, rest)
          [] -> error "highlight.js response list ended early")
        pure (CodeBlock language (map toInline (responseNodes response)))
      BulletList items -> BulletList <$> mapM (mapM applyBlock) items
      OrderedList start items -> OrderedList start <$> mapM (mapM applyBlock) items
      BlockQuote nested -> BlockQuote <$> mapM applyBlock nested
      Footnotes notes -> Footnotes <$> mapM applyFootnote notes
      other -> pure other
    applyFootnote note = do
      footnoteBody <- mapM applyBlock (footnoteBlocks note)
      pure note { footnoteBlocks = footnoteBody }
    toInline (NodeText value) = Text value
    toInline (NodeSpan className children) = Span className (map toInline children)
