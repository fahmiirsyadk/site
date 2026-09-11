-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The colour theme, as a domain type.
--
-- The theme is unusual in that it lives in two places at once: in this model,
-- and as a @dark@ class on @\<html\>@ that sits outside Miso's tree. The class
-- is what Tailwind's @dark:@ variants read, and it is applied by an inline
-- script before first paint to avoid a flash. 'Site.Update' keeps the two in
-- step; see 'Site.Platform.applyTheme'.
module Site.Theme
  ( Theme (..)
  , toggle
  , storageName
  , parseStorageName
  , toggleLabel
  ) where
-----------------------------------------------------------------------------
import    Miso.String (MisoString)
-----------------------------------------------------------------------------
data Theme
  = Light
  | Dark
  deriving (Show, Eq)
-----------------------------------------------------------------------------
toggle :: Theme -> Theme
toggle = \case
  Light -> Dark
  Dark  -> Light
-----------------------------------------------------------------------------
-- | The @localStorage@ representation. Lower case, matching the anti-flash
-- script in @index.html@.
storageName :: Theme -> MisoString
storageName = \case
  Light -> "light"
  Dark  -> "dark"
-----------------------------------------------------------------------------
-- | 'Nothing' for an absent or unrecognised value, which means "follow the
-- operating system" rather than "light".
parseStorageName :: MisoString -> Maybe Theme
parseStorageName = \case
  "light" -> Just Light
  "dark"  -> Just Dark
  _       -> Nothing
-----------------------------------------------------------------------------
-- | Accessible name for the toggle, describing the destination rather than
-- the current state.
toggleLabel :: Theme -> MisoString
toggleLabel = \case
  Light -> "Use dark theme"
  Dark  -> "Use light theme"
-----------------------------------------------------------------------------
