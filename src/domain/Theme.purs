module Domain.Theme where

import Prelude

data Theme
  = Light
  | Dark

fromString :: String -> Theme
fromString value =
  if value == "Dark" then Dark else Light

toString :: Theme -> String
toString theme = case theme of
  Light -> "Light"
  Dark -> "Dark"

toggle :: Theme -> Theme
toggle theme = case theme of
  Light -> Dark
  Dark -> Light
