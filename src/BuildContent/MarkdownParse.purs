module BuildContent.MarkdownParse (parse) where

import MarkdownIt (MdToken)

foreign import parse :: String -> Array MdToken
