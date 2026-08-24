module Interop.Content where

import Data.Function.Uncurried (Fn1, runFn1)

type Post =
  { title :: String
  , date :: String
  , slug :: String
  , section :: String
  , status :: String
  , excerpt :: String
  , banner :: String
  , ogTitle :: String
  , ogDescription :: String
  , ogImage :: String
  , html :: String
  }

foreign import posts :: Array Post
foreign import formatDateImpl :: Fn1 String String

formatDate :: String -> String
formatDate = runFn1 formatDateImpl
