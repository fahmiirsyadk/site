-- | Lightweight static highlighting for fenced code / diff lines (build-time HTML only).
module BuildContent.CodeHighlight
  ( highlightCodeLine
  ) where

import Prelude

import Data.Array as Array
import Data.Int (rem)
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits as CU

escapeHtml :: String -> String
escapeHtml =
  String.replaceAll (String.Pattern "&") (String.Replacement "&amp;")
    >>> String.replaceAll (String.Pattern "<") (String.Replacement "&lt;")
    >>> String.replaceAll (String.Pattern ">") (String.Replacement "&gt;")
    >>> String.replaceAll (String.Pattern "\"") (String.Replacement "&quot;")

keywords :: Array String
keywords =
  [ "let", "in", "if", "then", "else", "case", "of", "do", "where"
  , "type", "data", "newtype", "class", "instance", "import", "module"
  , "forall", "true", "false", "null", "undefined"
  , "var", "const", "function", "return", "export", "default", "async", "await"
  , "struct", "enum", "impl", "trait", "pub", "use", "fn", "mut"
  , "Array", "Maybe", "Either", "String", "Int", "Number", "Boolean", "Effect", "Unit", "Void"
  ]

isKeyword :: String -> Boolean
isKeyword w = Array.elem w keywords

isIdStart :: Char -> Boolean
isIdStart c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'

isIdCont :: Char -> Boolean
isIdCont c = isIdStart c || isDigit c || c == '\''

isDigit :: Char -> Boolean
isDigit c = c >= '0' && c <= '9'

takeWhileStr :: (Char -> Boolean) -> String -> String
takeWhileStr p s = CU.fromCharArray $ Array.takeWhile p $ CU.toCharArray s

dropChars :: Int -> String -> String
dropChars n s = CU.drop n s

countTrailingBackslashesBefore :: Int -> String -> Int
countTrailingBackslashesBefore idx s =
  if idx < 0 then 0
  else case CU.charAt idx s of
    Just '\\' -> 1 + countTrailingBackslashesBefore (idx - 1) s
    _ -> 0

isEscapedDoubleQuoteAt :: String -> Int -> Boolean
isEscapedDoubleQuoteAt s i =
  let bs = countTrailingBackslashesBefore (i - 1) s
  in bs `rem` 2 == 1

findClosingDoubleQuote :: String -> Maybe Int
findClosingDoubleQuote s =
  let
    n = String.length s
    go i =
      if i >= n then Nothing
      else
        case CU.charAt i s of
          Just '"' ->
            if isEscapedDoubleQuoteAt s i then go (i + 1) else Just i
          _ -> go (i + 1)
  in
    go 0

takeIdent :: String -> { word :: String, rest :: String }
takeIdent s =
  case CU.uncons s of
    Nothing -> { word: "", rest: "" }
    Just { head: h, tail: t } ->
      if isIdStart h then
        let
          tailPart = takeWhileStr isIdCont t
          n = String.length tailPart
        in
          { word: CU.singleton h <> tailPart, rest: dropChars n t }
      else
        { word: "", rest: s }

takeNumber :: String -> Maybe { num :: String, rest :: String }
takeNumber s =
  case CU.uncons s of
    Nothing -> Nothing
    Just { head: h, tail: t } ->
      if not (isDigit h) then Nothing
      else
        let
          intPart = takeWhileStr isDigit t
          afterInt = dropChars (String.length intPart) t
        in
          if CU.take 1 afterInt == "." then
            let
              fracPart = takeWhileStr isDigit (CU.drop 1 afterInt)
              nFrac = String.length fracPart
            in
              Just
                { num: CU.singleton h <> intPart <> "." <> fracPart
                , rest: dropChars (1 + nFrac) afterInt
                }
          else
            Just { num: CU.singleton h <> intPart, rest: afterInt }

scanLine :: String -> String
scanLine rem =
  case CU.uncons rem of
    Nothing -> ""
    Just { head: h, tail: t } ->
      if h == '"' then
        case findClosingDoubleQuote t of
          Just k ->
            let
              inner = CU.take k t
              after = CU.drop (k + 1) t
              quoted = "\"" <> inner <> "\""
            in
              "<span class=\"text-sky-600\">" <> escapeHtml quoted <> "</span>" <> scanLine after
          Nothing ->
            "<span class=\"text-sky-600\">" <> escapeHtml (CU.singleton h <> t) <> "</span>"
      else if isDigit h then
        case takeNumber rem of
          Just { num, rest } ->
            "<span class=\"text-amber-600\">" <> escapeHtml num <> "</span>" <> scanLine rest
          Nothing ->
            escapeHtml (CU.singleton h) <> scanLine t
      else if isIdStart h then
        case takeIdent rem of
          { word, rest } ->
            if word == "" then escapeHtml (CU.singleton h) <> scanLine t
            else if isKeyword word then
              "<span class=\"text-violet-700\">" <> escapeHtml word <> "</span>" <> scanLine rest
            else
              escapeHtml word <> scanLine rest
      else
        escapeHtml (CU.singleton h) <> scanLine t

-- | Full-line `--` / `//` comments, then token scan for strings, numbers, keywords.
highlightCodeLine :: String -> String
highlightCodeLine line =
  let
    trimmed = String.trim line
  in
    if CU.take 2 trimmed == "--" || CU.take 2 trimmed == "//" then
      "<span class=\"text-neutral-500 italic\">" <> escapeHtml line <> "</span>"
    else
      scanLine line
