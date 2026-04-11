module Routes where

import Prelude

import Control.Alt ((<|>))
import Data.Either (hush)
import Data.Generic.Rep (Argument(..), Product(..))
import Data.Maybe (Maybe)
import Data.String as String
import Luna.Routing (RouteCodec)
import Routing.Duplex (RouteDuplex(..), RouteDuplex', end, parse, print, root, segment, prefix)
import Routing.Duplex.Generic (gRouteDuplexCtr, product)
import Types (Route(..))

-- | Hand-rolled duplex (no `Generic Route`): matches the former `sum` layout
-- | — declaration order Home, About, SectionIndex, SectionPost (Generic sum order).
routeCodec :: RouteDuplex' Route
routeCodec =
  RouteDuplex enc dec
  where
  RouteDuplex homeEnc homeDec = root $ end $ pure Home
  RouteDuplex aboutEnc aboutDec = root $ end $ prefix "about" $ pure About
  RouteDuplex idxEnc idxDec = root $ end $ segment
  RouteDuplex rawPostEnc rawPostDec = root $ end $ product segment (gRouteDuplexCtr segment)

  enc = case _ of
    Home -> homeEnc Home
    About -> aboutEnc About
    SectionIndex s -> idxEnc s
    SectionPost s1 s2 -> rawPostEnc (Product (Argument s1) (Argument s2))

  dec =
    homeDec
      <|> aboutDec
      <|> (SectionIndex <$> idxDec)
      <|> (fromProduct <$> rawPostDec)
    where
    fromProduct (Product (Argument a) (Argument b)) = SectionPost a b

printRoutePath :: Route -> String
printRoutePath = print routeCodec

normalizePath :: String -> String
normalizePath raw =
  let
    withLeadingSlash =
      if String.take 1 raw == "/" then raw else "/" <> raw
    -- Strip trailing slash for consistency, but keep root "/" intact
    withoutTrailingSlash =
      if withLeadingSlash /= "/" && String.drop (String.length withLeadingSlash - 1) withLeadingSlash == "/"
        then String.take (String.length withLeadingSlash - 1) withLeadingSlash
        else withLeadingSlash
  in
    withoutTrailingSlash

parseRoutePath :: String -> Maybe Route
parseRoutePath path = hush $ parse routeCodec (normalizePath path)

lunaRouteCodec :: RouteCodec Route
lunaRouteCodec =
  { parse: parseRoutePath
  , print: printRoutePath
  }