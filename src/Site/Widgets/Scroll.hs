-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | DOM measurement for the reading rail, ported from the source's
-- @Platform.Browser.Scroll.ts@. The scroll listener itself is a Miso
-- @on "scroll"@ attribute on the content container; this module only reads
-- the geometry and performs track clicks.
--
-- Like the other widget modules it is written against "Miso.DSL" and never
-- runs on the native targets.
module Site.Widgets.Scroll
  ( measureReadingProgress
  , scrollToProgress
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (forM, unless, void)
import           Data.Char (digitToInt)
import           Prelude hiding ((!!))
import           Miso.DSL
  ( create
  , fromJSValUnchecked
  , jsg
  , setField
  , (!)
  , (#)
  , (!!)
  )
import           Miso.String (MisoString, unpack)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Platform (prefersReducedMotion)
import           Site.Scroll
import           Site.Widgets.Gl (int, isAbsent, number)
-----------------------------------------------------------------------------
-- | Measure the scroll container, its content, and every anchored heading,
-- then resolve the rail percentages. Returns an empty progress when the post
-- is not on screen.
measureReadingProgress :: IO ReadingProgress
measureReadingProgress = do
  document <- jsg "document"
  root <- document # "querySelector" $ Config.contentScrollSelector
  content <- document # "querySelector" $ Config.postProseSelector
  rootAbsent <- isAbsent root
  contentAbsent <- isAbsent content
  if rootAbsent || contentAbsent
    then pure emptyReadingProgress
    else do
      scrollTop <- number root "scrollTop"
      scrollHeight <- number root "scrollHeight"
      clientHeight <- number root "clientHeight"
      rootRect <- root # "getBoundingClientRect" $ ()
      rootTop <- number rootRect "top"
      nodes <- content # "querySelectorAll" $ Config.postHeadingSelector
      count <- int nodes "length"
      headings <- forM [0 .. count - 1] $ \index -> do
        node <- nodes !! index
        identifier <- fromJSValUnchecked =<< node ! "id"
        tagName <- fromJSValUnchecked =<< node ! "tagName"
        rect <- node # "getBoundingClientRect" $ ()
        top <- number rect "top"
        pure HeadingGeometry
          { geomId = identifier
          , geomLevel = levelFromTagName tagName
          , geomTop = top
          }
      pure (readingProgress Geometry
        { geometryScrollTop = scrollTop
        , geometryScrollHeight = scrollHeight
        , geometryClientHeight = clientHeight
        , geometryRootTop = rootTop
        , geometryHeadings = filter (not . null . geomId) headings
        })
-----------------------------------------------------------------------------
-- | Scroll the container so the given rail percentage is at the top. Smooth
-- unless the reader prefers reduced motion, matching the source.
scrollToProgress :: Int -> IO ()
scrollToProgress percent = do
  document <- jsg "document"
  root <- document # "querySelector" $ Config.contentScrollSelector
  absent <- isAbsent root
  unless absent $ do
    scrollHeight <- number root "scrollHeight"
    clientHeight <- number root "clientHeight"
    reduced <- prefersReducedMotion
    options <- create
    setField options "top"
      (progressScrollTarget (max 0.0 (scrollHeight - clientHeight)) percent :: Double)
    setField options "behavior"
      (if reduced then "auto" else "smooth" :: MisoString)
    void $ root # "scrollTo" $ [options]
-----------------------------------------------------------------------------
-- | @H2@ -> 2. Anything unexpected falls back to the outermost level, which
-- is the base tick class.
levelFromTagName :: MisoString -> Int
levelFromTagName tagName = case unpack tagName of
  ('H' : digit : _) | digit >= '2' && digit <= '4' -> digitToInt digit
  _ -> 2
