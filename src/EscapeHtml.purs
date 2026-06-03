module EscapeHtml
  ( escapeHtml
  , escapeAttr
  ) where

import Prelude

import Data.String as String

escapeHtml :: String -> String
escapeHtml =
  String.replaceAll (String.Pattern "&") (String.Replacement "&amp;")
    >>> String.replaceAll (String.Pattern "<") (String.Replacement "&lt;")
    >>> String.replaceAll (String.Pattern ">") (String.Replacement "&gt;")
    >>> String.replaceAll (String.Pattern "\"") (String.Replacement "&quot;")
    >>> String.replaceAll (String.Pattern "'") (String.Replacement "&#39;")

escapeAttr :: String -> String
escapeAttr = escapeHtml
