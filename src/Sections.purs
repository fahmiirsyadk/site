module Sections
  ( SectionConfig
  , sectionConfig
  , extraTagsForSection
  , isThoughtSection
  ) where

import Prelude

type SectionConfig =
  { name :: String
  , kind :: String
  , extraTags :: Array String
  }

-- | Single source of truth for content folder semantics.
-- | `kind` is currently either "post" or "thought".
sectionConfig :: String -> SectionConfig
sectionConfig name =
  case name of
    "thoughts" ->
      { name, kind: "thought", extraTags: [] }
    "til" ->
      { name, kind: "post", extraTags: [ "til" ] }
    _ ->
      { name, kind: "post", extraTags: [] }

isThoughtSection :: String -> Boolean
isThoughtSection name = (sectionConfig name).kind == "thought"

extraTagsForSection :: String -> Array String
extraTagsForSection name = (sectionConfig name).extraTags

