module ManifestCodec (decodeSiteManifestString) where

import Prelude

import Data.Argonaut.Decode (decodeJson) as AD
import Data.Argonaut.Parser (jsonParser) as Parser
import Data.Bifunctor (lmap)
import Data.Either (Either)
import Types (SiteManifest)

decodeSiteManifestString :: String -> Either String SiteManifest
decodeSiteManifestString content = do
  json <- Parser.jsonParser content
  lmap (const "Failed to decode site manifest JSON") (AD.decodeJson json)
