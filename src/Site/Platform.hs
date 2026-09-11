-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | Every effect that reaches outside the model.
--
-- Concentrating them here buys two things. Effects stay out of 'Site.View',
-- which the native prerender generator must be able to evaluate; and
-- 'Site.Update' stays readable, because each of these is one named idea
-- rather than a chain of property lookups.
--
-- Note what is /not/ here: @foreign import javascript@, and therefore CPP.
-- Everything below goes through "Miso.DSL" or
-- 'Control.Concurrent.threadDelay', all of which are type-correct on the
-- native back-end (where the JavaScript primitives are bottom and never
-- forced) as well as under WASM. One source, two targets, no @#ifdef@.
module Site.Platform
  ( -- * Timing
    delayMs
    -- * Media queries
  , prefersReducedMotion
  , prefersDarkColorScheme
    -- * Theme
  , bootTheme
  , applyTheme
  , storeTheme
  , readStoredTheme
    -- * Scroll
  , resetContentScroll
    -- * Link interception
  , installInternalLinkGuard
    -- * JavaScript values
  , isAbsent
  ) where
-----------------------------------------------------------------------------
import           Control.Concurrent (threadDelay)
import           Control.Monad (void, when)
import           Miso.DSL
                 ( JSVal
                 , Object (..)
                 , fromJSVal
                 , freeJSVal
                 , isNull
                 , isUndefined
                 , jsNull
                 , jsg
                 , jsgf
                 , setProp
                 , syncCallback1
                 , (!)
                 , (#)
                 )
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Theme (Theme (..))
import qualified Site.Theme as Theme
-----------------------------------------------------------------------------
delayMs :: Int -> IO ()
delayMs milliseconds = threadDelay (milliseconds * 1000)
-----------------------------------------------------------------------------
-- | True when a JavaScript value is @null@ or @undefined@. Shared by the
-- platform effects and the widgets so every absence check is the same.
isAbsent :: JSVal -> IO Bool
isAbsent value = (||) <$> isNull value <*> isUndefined value
-----------------------------------------------------------------------------
-- | @window.matchMedia(query).matches@, defaulting to 'False' when the query
-- cannot be answered.
matchMedia :: MisoString -> IO Bool
matchMedia query = do
  function <- jsgf "Function"
    ( "query" :: MisoString
    , "try { return window.matchMedia(query).matches === true; } catch (_) { return false; }" :: MisoString
    )
  result <- function # "call" $ (jsNull, query)
  answer <- fromJSVal result
  pure (answer == Just True)
-----------------------------------------------------------------------------
-- | Honoured by suppressing the route-leave delay: a reader who has asked for
-- less motion should not also be made to wait for it.
prefersReducedMotion :: IO Bool
prefersReducedMotion = matchMedia "(prefers-reduced-motion: reduce)"
-----------------------------------------------------------------------------
-- | Consulted only when @localStorage@ holds no explicit choice.
prefersDarkColorScheme :: IO Bool
prefersDarkColorScheme = matchMedia Config.prefersDarkQuery
-----------------------------------------------------------------------------
-- | The theme the reader should see: the stored choice when valid, the system
-- preference otherwise. This is the same decision the anti-flash script makes
-- in the generated page, expressed once so boot and the post-mount adoption
-- cannot drift apart.
bootTheme :: IO Theme
bootTheme = do
  stored <- readStoredTheme
  case stored of
    Just explicit -> pure explicit
    Nothing -> do
      dark <- prefersDarkColorScheme
      pure (if dark then Dark else Light)
-----------------------------------------------------------------------------
-- | Write the theme to the @dark@ class on @\<html\>@, which is where
-- Tailwind's @dark:@ variants read it. That element sits outside Miso's tree,
-- so the class cannot be expressed as an attribute in the view.
applyTheme :: Theme -> IO ()
applyTheme chosen = do
  element <- jsg "document" >>= (! "documentElement")
  classes <- element ! "classList"
  void $ classes # "toggle" $ (Config.darkClassName, chosen == Dark)
-----------------------------------------------------------------------------
storeTheme :: Theme -> IO ()
storeTheme chosen = safeStorageSet Config.themeStorageKey (Theme.storageName chosen)
-----------------------------------------------------------------------------
-- | 'Nothing' when the reader has expressed no preference, which is distinct
-- from having chosen light.
readStoredTheme :: IO (Maybe Theme)
readStoredTheme = do
  stored <- safeStorageGet Config.themeStorageKey
  pure (stored >>= Theme.parseStorageName)
-----------------------------------------------------------------------------
-- Miso's resolved WASM DSL does not turn exceptions from synchronous unsafe
-- JavaScript imports into catchable Haskell 'JSException' values. Keep these
-- optional browser capabilities inside JavaScript try/catch blocks, then
-- marshal only safe Bool/Maybe results across the boundary.
--
-- These fixed functions also work before startApp installs Miso's runtime:
-- the QQ inline helper is unavailable during bootModel. All variable data is
-- passed as arguments, never interpolated into executable source. No helper
-- globals from index.html are needed by interactive startup.
safeStorageGet :: MisoString -> IO (Maybe MisoString)
safeStorageGet key = do
  function <- jsgf "Function"
    ( "key" :: MisoString
    , "try { return window.localStorage.getItem(key); } catch (_) { return null; }" :: MisoString
    )
  result <- function # "call" $ (jsNull, key)
  fromJSVal result

safeStorageSet :: MisoString -> MisoString -> IO ()
safeStorageSet key value = do
  function <- jsgf "Function"
    ( "key" :: MisoString
    , "value" :: MisoString
    , "try { window.localStorage.setItem(key, value); } catch (_) {}" :: MisoString
    )
  void $ function # "call" $ (jsNull, key, value)
-----------------------------------------------------------------------------
-- | Return the scrolling container to the top on a route change. The
-- container scrolls, not the window, so @window.scrollTo@ would do nothing.
resetContentScroll :: IO ()
resetContentScroll = do
  element <- jsg "document" # "querySelector" $ [Config.contentScrollSelector]
  absent <- isAbsent element
  if absent
    then pure ()
    else void $ element # "scrollTo" $ (0 :: Int, 0 :: Int)
-----------------------------------------------------------------------------
-- | Install the one synchronous browser-boundary listener that makes ordinary
-- internal links SPA-owned while leaving modified and non-primary clicks to
-- the browser. The callback is retained on the document so a hot reload can
-- remove and replace it instead of accumulating listeners.
installInternalLinkGuard :: IO ()
installInternalLinkGuard = do
  document <- jsg "document"
  old <- document ! Config.internalLinkGuardProperty
  oldAbsent <- isAbsent old
  when (not oldAbsent) $ do
    void $ document # "removeEventListener" $ ("click" :: MisoString, old, True)
    freeJSVal old
  callback <- syncCallback1 $ \event -> do
    target <- event ! "target"
    anchor <- target # "closest" $ Config.internalLinkSelector
    absent <- isAbsent anchor
    when (not absent) $ do
      button <- (fromJSVal =<< event ! "button") :: IO (Maybe Int)
      ctrl <- (fromJSVal =<< event ! "ctrlKey") :: IO (Maybe Bool)
      meta <- (fromJSVal =<< event ! "metaKey") :: IO (Maybe Bool)
      shift <- (fromJSVal =<< event ! "shiftKey") :: IO (Maybe Bool)
      alt <- (fromJSVal =<< event ! "altKey") :: IO (Maybe Bool)
      let primary = maybe True (== 0) button
          modified = any (== Just True) [ctrl, meta, shift, alt]
      when (primary && not modified) (void $ event # "preventDefault" $ ())
  setProp Config.internalLinkGuardProperty callback (Object document)
  void $ document # "addEventListener" $ ("click" :: MisoString, callback, True)
