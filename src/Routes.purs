module Routes where

import Prelude hiding ((/))

import Data.Either (hush)
import Data.Maybe (Maybe)
import Data.String as String
import Luna.Routing (RouteCodec)
import Routing.Duplex (RouteDuplex', parse, print, root, segment)
import Types (Route)
import Routing.Duplex.Generic (noArgs, sum)
import Routing.Duplex.Generic.Syntax ((/))
routeCodec ::
  RouteDuplex' Route
routeCodec =
  root $ sum
    { "Home": noArgs
    , "About": "about" / noArgs
    , "SectionPost": segment / segment
    , "SectionIndex": segment
    }

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