-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The URL grammar, and nothing else.
--
-- 'Route' is the wire format: it says what a path means, and it is total --
-- every string maps to some 'Route', with 'NotFound' as the bottom. It holds
-- no page state. The live counterpart is 'Site.Model.Page'.
--
-- Every path carries a trailing slash except the root, matching the deployed
-- URLs of the site this replaces.
--
-- __Portability:__ 'Miso.String.MisoString' is 'Data.Text.Text' natively and
-- @JSString@ under WASM, and the two share only a small API. The splitting
-- and joining below therefore happens in 'String', reached through
-- @pack@/@unpack@, which both back-ends provide.
module Site.Route
  ( Route (..)
    -- * Parsing
  , urlToRoute
  , uriToRoute
    -- * Printing
  , routePath
  , routeURI
    -- * Queries
  , isContentSection
  , activeSection
  , normalizePath
  ) where
-----------------------------------------------------------------------------
import           Data.List (intercalate)
import           Miso (URI (..), emptyURI)
import           Miso.String (MisoString)
import qualified Miso.String as MS
-----------------------------------------------------------------------------
import qualified Site.Section as Section
-----------------------------------------------------------------------------
data Route
  = Home
  -- ^ @/@
   | Section Section.Section
  -- ^ @/thought/@, @/lab/@ -- the argument is always in
  -- 'Site.Config.contentSections'.
   | Post Section.Section MisoString
  -- ^ @/thought/{slug}/@ -- section then slug.
  | NotFound MisoString
  -- ^ Anything else. The argument is the /normalised/ path, so that
  -- @'urlToRoute' . 'routePath'@ is the identity on this constructor too.
  deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | Split a path into non-empty segments, discarding leading, trailing and
-- repeated slashes. @"/a//b/"@ and @"a/b"@ both give @["a","b"]@.
normalizePath :: MisoString -> [MisoString]
normalizePath = map MS.pack . filter (not . null) . splitOn '/' . MS.unpack
-----------------------------------------------------------------------------
splitOn :: Char -> String -> [String]
splitOn c s =
  case break (== c) s of
    (chunk, [])       -> [chunk]
    (chunk, _ : rest) -> chunk : splitOn c rest
-----------------------------------------------------------------------------
isContentSection :: MisoString -> Bool
isContentSection = maybe False (const True) . Section.parseSection
-----------------------------------------------------------------------------
-- | Total. Unrecognised shapes become 'NotFound' carrying their normalised
-- form, never an error.
urlToRoute :: MisoString -> Route
urlToRoute raw =
  case normalizePath raw of
    []                                            -> Home
    [rawSection] | Just section <- Section.parseSection rawSection -> Section section
    [rawSection, slug] | Just section <- Section.parseSection rawSection -> Post section slug
    parts                                         -> NotFound (rejoin parts)
  where
    rejoin = MS.pack . ("/" <>) . intercalate "/" . map MS.unpack
-----------------------------------------------------------------------------
-- | Absolute path, with the leading slash. Inverse of 'urlToRoute' on every
-- 'Route' that 'urlToRoute' can produce.
routePath :: Route -> MisoString
routePath = \case
  Home              -> "/"
  Section section   -> "/" <> Section.sectionName section <> "/"
  Post section slug -> "/" <> Section.sectionName section <> "/" <> slug <> "/"
  NotFound path     -> path
-----------------------------------------------------------------------------
-- | Only the path is read. Query and fragment are carried by the 'URI' but do
-- not select a page; fragment-scrolling is a separate concern.
uriToRoute :: URI -> Route
uriToRoute = urlToRoute . uriPath
-----------------------------------------------------------------------------
-- | 'Miso.prettyURI' renders @"/" <> uriPath@, so 'uriPath' must not carry a
-- leading slash of its own or the pushed URL gains a second one.
routeURI :: Route -> URI
routeURI target = emptyURI
  { uriPath = MS.pack (dropWhile (== '/') (MS.unpack (routePath target)))
  }
-----------------------------------------------------------------------------
-- | Which navigation item is current. Empty for routes with no nav entry.
activeSection :: Route -> Maybe Section.Section
activeSection = \case
   Section section -> Just section
   Post section _  -> Just section
   Home            -> Nothing
   NotFound _      -> Nothing
-----------------------------------------------------------------------------
