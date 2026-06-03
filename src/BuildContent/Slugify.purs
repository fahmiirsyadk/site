module BuildContent.Slugify (slugify) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as CU
import Data.String.Pattern (Pattern(..), Replacement(..))

slugify :: String -> String
slugify text =
  let
    step1 = String.replaceAll (Pattern "<") (Replacement "") $ String.replaceAll (Pattern ">") (Replacement "") text
    lower = String.toLower step1
    chars = CU.toCharArray lower
    keep c =
      (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == ' ' || c == '-'
    cleaned = CU.fromCharArray $ Array.filter keep chars
    dashed = String.replaceAll (Pattern " ") (Replacement "-") cleaned
    collapsed = collapseDashes dashed
  in
    String.trim collapsed

collapseDashes :: String -> String
collapseDashes s =
  case String.indexOf (Pattern "--") s of
    Nothing -> s
    Just _ -> collapseDashes $ String.replaceAll (Pattern "--") (Replacement "-") s
