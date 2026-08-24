module Runtime.Scribble where

import Prelude

import Data.Array as Array
import Data.Maybe (fromMaybe)

type ScribbleVariant =
  { index :: Int
  , path :: String
  }

type ScribbleAnimation =
  { frames :: Array { dashOffset :: Number, offset :: Number }
  , duration :: Int
  , easing :: String
  , fill :: String
  }

variants :: Array String
variants =
  [ "M8 38Q12 8 43 12 76 16 57 45 38 70 20 48 0 24 47 6 92-4 111 25 128 52 83 51 35 49 61 13 84-12 105 36 118 72 68 61 17 50 31 17 41-8 79 17 112 38 75 66 35 82 14 43-2 13 49 20 103 27 88 55 73 78 42 47 12 17 55 5 98-5 119 31 129 60 82 42 37 24 47 59 55 79 91 53 122 32 97 14 71-4 28 31 5 54 52 67 100 76 109 38 116 6 66 25 22 43 41 8 62-10 89 30 108 58 65 55 26 52 21 31 17 9 60 16 104 22 93 48 80 70 48 40 22 15 71 7 116 1 119 39 120 68 72 48 29 31 8 38"
  , "M4 24Q27 58 59 23 90-10 119 29 137 56 83 64 25 72 17 33 9-6 64 9 118 24 98 57 76 86 41 51 8 20 47 2 87-15 112 18 129 42 87 45 42 48 61 17 77-9 103 33 120 70 69 59 14 49 29 15 45-11 79 25 108 54 62 68 17 76 7 39-2 12 42 19 89 28 75 56 59 81 25 45 4 24 4 24"
  , "M9 56C31 3 76 79 111 14C125-9 57 4 32 60C18 88 94 60 119 38C136 22 77 14 48 34C13 57 48 71 90 58C119 49 85-2 53 11C21 24 11 68 9 56C5 38 42 2 75 18C112 36 92 70 54 51C20 34 48 8 102 27C127 36 99 59 68 39C37 19 19 44 9 56"
  , "M5 39C7 5 54 2 49 35C44 69 2 60 18 19C31-12 91 2 78 42C67 77 22 44 42 13C61-16 125 14 105 49C88 80 43 33 68 9C94-14 138 23 111 58C87 85 60 31 91 17C118 5 126 52 95 59C61 66 31 15 58 7C91-2 119 44 83 50C46 56 13 36 5 39"
  ]

variantCount :: Int
variantCount = Array.length variants

selectScribble :: Int -> Int -> ScribbleVariant
selectScribble previousIndex candidate =
  let normalized = candidate `mod` variantCount
      index = if normalized == previousIndex then (normalized + 1) `mod` variantCount else normalized
  in
    { index
    , path: fromMaybe "" (Array.index variants index)
    }

scribbleAnimation :: Number -> ScribbleAnimation
scribbleAnimation pathLength =
  { frames:
      [ { dashOffset: pathLength, offset: 0.0 }
      , { dashOffset: 0.0, offset: 0.24 }
      , { dashOffset: 0.0, offset: 0.68 }
      , { dashOffset: -pathLength, offset: 1.0 }
      ]
  , duration: 2800
  , easing: "cubic-bezier(0.65, 0, 0.35, 1)"
  , fill: "forwards"
  }
