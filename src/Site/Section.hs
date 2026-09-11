{-# LANGUAGE OverloadedStrings #-}

-- | The finite vocabulary shared by frontmatter, routes, and navigation.
module Site.Section (Section (..), sectionName, parseSection, allSections) where

import Miso.String (MisoString)

data Section = Thought | Lab
  deriving (Show, Eq, Ord, Enum, Bounded)

allSections :: [Section]
allSections = [minBound .. maxBound]

sectionName :: Section -> MisoString
sectionName Thought = "thought"
sectionName Lab = "lab"

parseSection :: MisoString -> Maybe Section
parseSection "thought" = Just Thought
parseSection "lab" = Just Lab
parseSection _ = Nothing
