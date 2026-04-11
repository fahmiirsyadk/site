module ManifestCodec (decodeSiteManifestString, decodePostJson) where

import Prelude

import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (decodeJson)
import Data.Argonaut.Decode.Error (JsonDecodeError, printJsonDecodeError)
import Data.Argonaut.Parser (jsonParser) as Parser
import Data.Either (Either(..))
import Types (Post, SiteManifest)

decodePostJson :: Json -> Either JsonDecodeError Post
decodePostJson = decodeJson

decodeSiteManifestString :: String -> Either String SiteManifest
decodeSiteManifestString content = do
  json <- Parser.jsonParser content
  case decodeJson json of
    Left e -> Left (printJsonDecodeError e)
    Right m -> Right m
