-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The random scribble's variants and animation plan, ported from the
-- source's @Runtime.Scribble@. Pure: the DOM mechanics live in
-- 'Site.Widgets.Scribble'.
module Site.Scribble
  ( ScribbleFrame (..)
  , ScribbleAnimation (..)
  , scribbleVariantCount
  , scribblePathAt
  , selectScribble
  , scribbleAnimation
  ) where
-----------------------------------------------------------------------------
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
-- | The four hand-drawn strokes. The widget cycles randomly through them,
-- never repeating one twice in a row.
scribbleVariants :: [MisoString]
scribbleVariants =
  [ "M8 38Q12 8 43 12 76 16 57 45 38 70 20 48 0 24 47 6 92-4 111 25 128 52 83 51 35 49 61 13 84-12 105 36 118 72 68 61 17 50 31 17 41-8 79 17 112 38 75 66 35 82 14 43-2 13 49 20 103 27 88 55 73 78 42 47 12 17 55 5 98-5 119 31 129 60 82 42 37 24 47 59 55 79 91 53 122 32 97 14 71-4 28 31 5 54 52 67 100 76 109 38 116 6 66 25 22 43 41 8 62-10 89 30 108 58 65 55 26 52 21 31 17 9 60 16 104 22 93 48 80 70 48 40 22 15 71 7 116 1 119 39 120 68 72 48 29 31 8 38"
  , "M4 24Q27 58 59 23 90-10 119 29 137 56 83 64 25 72 17 33 9-6 64 9 118 24 98 57 76 86 41 51 8 20 47 2 87-15 112 18 129 42 87 45 42 48 61 17 77-9 103 33 120 70 69 59 14 49 29 15 45-11 79 25 108 54 62 68 17 76 7 39-2 12 42 19 89 28 75 56 59 81 25 45 4 24 4 24"
  , "M9 56C31 3 76 79 111 14C125-9 57 4 32 60C18 88 94 60 119 38C136 22 77 14 48 34C13 57 48 71 90 58C119 49 85-2 53 11C21 24 11 68 9 56C5 38 42 2 75 18C112 36 92 70 54 51C20 34 48 8 102 27C127 36 99 59 68 39C37 19 19 44 9 56"
  , "M5 39C7 5 54 2 49 35C44 69 2 60 18 19C31-12 91 2 78 42C67 77 22 44 42 13C61-16 125 14 105 49C88 80 43 33 68 9C94-14 138 23 111 58C87 85 60 31 91 17C118 5 126 52 95 59C61 66 31 15 58 7C91-2 119 44 83 50C46 56 13 36 5 39"
  ]
-----------------------------------------------------------------------------
scribbleVariantCount :: Int
scribbleVariantCount = length scribbleVariants
-----------------------------------------------------------------------------
scribblePathAt :: Int -> MisoString
scribblePathAt index =
  if index >= 0 && index < scribbleVariantCount
    then scribbleVariants !! index
    else ""
-----------------------------------------------------------------------------
-- | Pick a variant index from a random candidate, avoiding an immediate
-- repeat.
selectScribble :: Int -> Int -> Int
selectScribble previousIndex candidate =
  if normalized == previousIndex
    then (normalized + 1) `mod` scribbleVariantCount
    else normalized
  where
    normalized = candidate `mod` scribbleVariantCount
-----------------------------------------------------------------------------
data ScribbleFrame = ScribbleFrame
  { frameDashOffset :: Double
  , frameOffset     :: Double
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data ScribbleAnimation = ScribbleAnimation
  { animationFrames   :: [ScribbleFrame]
  , animationDuration :: Int
  , animationEasing   :: MisoString
  , animationFill     :: MisoString
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | The stroke draws in, pauses, then draws back out over 2.8 seconds.
scribbleAnimation :: Double -> ScribbleAnimation
scribbleAnimation pathLength = ScribbleAnimation
  { animationFrames =
      [ ScribbleFrame pathLength 0.0
      , ScribbleFrame 0.0 0.24
      , ScribbleFrame 0.0 0.68
      , ScribbleFrame (-pathLength) 1.0
      ]
  , animationDuration = 2800
  , animationEasing = "cubic-bezier(0.65, 0, 0.35, 1)"
  , animationFill = "forwards"
  }
