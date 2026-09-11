{-# LANGUAGE OverloadedStrings #-}

-- | Browser resources with explicit, idempotent ownership. Register cleanup
-- immediately after acquisition, so partial initialization rolls back too.
module Site.Widgets.Browser
  ( Scope, newScope, own, disposeScope, listen, observe, frameLoop
  , capturePointer, sameNode
  , Mount, newMount, mountElement, mountSelector, disposeElement, disposeMount
  ) where

import Control.Monad (void, when, unless, forM_, (>=>))
import Data.IORef
import Miso.DSL
import Miso.String (MisoString)
import qualified Site.FrameLoop as Frame
import Site.Platform (isAbsent)

newtype Scope = Scope (IORef (Maybe [IO ()]))

newScope :: IO Scope
newScope = Scope <$> newIORef (Just [])

own :: Scope -> IO () -> IO ()
own (Scope ref) cleanup = do
  closed <- atomicModifyIORef' ref $ \current -> case current of
    Nothing -> (Nothing, True)
    Just actions -> (Just (cleanup : actions), False)
  if closed then cleanup else pure ()

disposeScope :: Scope -> IO ()
disposeScope (Scope ref) = do
  actions <- atomicModifyIORef' ref (\current -> (Nothing, current))
  mapM_ sequence_ actions

listen :: Scope -> JSVal -> MisoString -> Bool -> (JSVal -> IO ()) -> IO ()
listen scope@(Scope ref) target kind capture handler = do
  open <- maybe False (const True) <$> readIORef ref
  when open $ do
    callback <- syncCallback1 handler
    void $ target # "addEventListener" $ (kind, callback, capture)
    own scope $ do
      void $ target # "removeEventListener" $ (kind, callback, capture)
      freeFunction (Function callback)

-- | Returns the observer so callers that must unobserve individual targets
-- keep a handle. Returns null on an already-closed scope or when the
-- constructor is unavailable. A 'Nothing' target creates the observer without
-- observing anything, which is how the dither registry adds roots later.
observe :: Scope -> MisoString -> Maybe JSVal -> Object -> (JSVal -> IO ()) -> IO JSVal
observe scope@(Scope ref) constructor target options handler = do
  open <- maybe False (const True) <$> readIORef ref
  if not open
    then pure jsNull
    else do
      callback <- syncCallback1 handler
      observer <- if constructor == "IntersectionObserver"
        then new (jsg constructor) (callback, options)
        else new (jsg constructor) callback
      own scope $ do
        void $ observer # "disconnect" $ ()
        freeFunction (Function callback)
      forM_ target $ \element ->
        if constructor == "IntersectionObserver"
          then void $ observer # "observe" $ [element]
          else void $ observer # "observe" $ (element, options)
      pure observer

frameLoop :: Scope -> Bool -> (Double -> IO ()) -> IO Frame.FrameLoop
frameLoop scope reduced draw = do
  loop <- Frame.newFrameLoop (if reduced then Frame.OnDemand else Frame.Continuous) install draw
  own scope (Frame.dispose loop)
  pure loop
  where
    install tick = do
      callback <- syncCallback1 (fromJSValUnchecked >=> tick)
      own scope (freeFunction (Function callback))
      pure Frame.FrameDriver
        { Frame.requestFrame = do
            window <- jsg "window"
            fromJSValUnchecked =<< (window # "requestAnimationFrame" $ [callback])
        , Frame.cancelFrame = \handle -> do
            window <- jsg "window"
            void $ window # "cancelAnimationFrame" $ [handle]
        }

capturePointer :: JSVal -> JSVal -> IO ()
capturePointer canvas event = do
  pointerId <- event ! "pointerId"
  void $ canvas # "setPointerCapture" $ [pointerId]

sameNode :: JSVal -> JSVal -> IO Bool
sameNode left right = do
  missing <- isAbsent left
  if missing
    then pure False
    else fromJSValUnchecked =<< (left # "isSameNode" $ [right])

-- | One explicitly owned mount slot. Publishing the slot before initialization
-- serializes duplicate hydration hooks. Retries belong to that exact element
-- and are cancelled with its scope.
data Mount = Mount (IORef (Maybe (JSVal, Scope))) (Scope -> JSVal -> IO Bool)

newMount :: (Scope -> JSVal -> IO Bool) -> IO Mount
newMount initialize = do
  current <- newIORef Nothing
  pure (Mount current initialize)

mountElement :: Mount -> JSVal -> IO ()
mountElement owner@(Mount ref initialize) element = do
  missing <- isAbsent element
  connected <- if missing then pure False else fromJSValUnchecked =<< element ! "isConnected"
  when connected $ do
    current <- readIORef ref
    same <- maybe (pure False) (sameNode element . fst) current
    unless same $ do
      disposeMount owner
      scope <- newScope
      writeIORef ref (Just (element, scope))
      let attempt count = do
            active <- scopeOpen scope
            attached <- fromJSValUnchecked =<< element ! "isConnected"
            when (active && attached) $ do
              finished <- initialize scope element
              unless (finished || count >= 40) $ do
                callback <- syncCallback1 (\_ -> attempt (count + 1))
                window <- jsg "window"
                handle <- window # "setTimeout" $ (callback, 500 :: Int)
                own scope $ do
                  void $ window # "clearTimeout" $ [handle]
                  freeFunction (Function callback)
      attempt (0 :: Int)

mountSelector :: Mount -> MisoString -> IO ()
mountSelector owner selector = do
  document <- jsg "document"
  element <- document # "querySelector" $ selector
  missing <- isNull element
  unless missing (mountElement owner element)

disposeElement :: Mount -> JSVal -> IO ()
disposeElement owner@(Mount ref _) element = do
  current <- readIORef ref
  same <- maybe (pure False) (sameNode element . fst) current
  when same (disposeMount owner)

disposeMount :: Mount -> IO ()
disposeMount (Mount ref _) = do
  current <- atomicModifyIORef' ref (\value -> (Nothing, value))
  mapM_ (disposeScope . snd) current

scopeOpen :: Scope -> IO Bool
scopeOpen (Scope ref) = maybe False (const True) <$> readIORef ref
