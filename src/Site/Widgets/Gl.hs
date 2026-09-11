-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The WebGL mechanics shared by the shader mounts, ported from the source
-- site's @Platform.Browser.Gl@.
--
-- Only what every mount uses is here: context attributes, program
-- compilation, parameter reads, context release, the JavaScript accessors
-- the widgets read values with, and the retry that covers a transiently
-- unavailable context. Draw calls stay next to the widget that owns them.
-- Like 'Site.Platform', this module is written against "Miso.DSL" rather than
-- @foreign import javascript@, so it compiles for the native test and
-- prerender targets, where the JavaScript primitives are never forced.
module Site.Widgets.Gl
  ( -- * Programs
    GlProgram (..)
  , compileProgram
  , deleteProgram
    -- * Textures
  , texImage2DNull
  , texImage2DWith
    -- * Contexts
  , releaseContext
  , isContextLost
    -- * JavaScript values
  , isAbsent
  , number
  , int
  , performanceNow
    -- * Scoped acquisition
  , acquire
  , optionalObject
  , uniformLocation
  , attribLocation
    -- * Parameters and logging
  , getParameterBool
  , getParameterInt
  , logError
    -- * Constants
    -- | WebGL enums are fixed by the specification and shared by WebGL1 and
    -- WebGL2, so the shared subset is named here instead of read back from
    -- each context.
  , glVertexShader
  , glFragmentShader
  , glCompileStatus
   , glLinkStatus
   , glTriangles
   , glTriangleStrip
  , glTexture2D
  , glTexture0
  , glTexture1
  , glTexture2
  , glLinear
  , glNearest
  , glClampToEdge
  , glRepeat
  , glLuminance
  , glTextureMagFilter
  , glTextureMinFilter
  , glTextureWrapS
  , glTextureWrapT
  , glRgba
  , glRgba8
  , glUnsignedByte
  , glFramebuffer
  , glColorAttachment0
  , glFramebufferComplete
  , glArrayBuffer
  , glStaticDraw
  , glFloat
  , glDepthTest
  , glLequal
  , glCullFace
  , glUnpackFlipY
  , glColorDepthBits
  ) where
-----------------------------------------------------------------------------
import           Control.Monad (unless, void, when)
import           Control.Monad.Trans.Class (lift)
import           Control.Monad.Trans.Maybe (MaybeT (..))
import           Miso.DSL
  ( JSVal
  , fromJSValUnchecked
  , jsg
  , jsNull
  , toJSVal
  , (!)
  , (#)
  )
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import           Site.Platform (isAbsent)
import qualified Site.Widgets.Browser as Browser
-----------------------------------------------------------------------------
data GlProgram = GlProgram
  { glProgram  :: JSVal
  , glVertex   :: JSVal
  , glFragment :: JSVal
  }
-----------------------------------------------------------------------------
-- | Compile and link a vertex/fragment pair. Logs and returns 'Nothing' on
-- any failure, releasing whatever was already created.
compileProgram :: JSVal -> MisoString -> MisoString -> MisoString -> IO (Maybe GlProgram)
compileProgram gl vertexSource fragmentSource label = do
  mVertex <- compileShader gl glVertexShader vertexSource (label <> " vertex")
  case mVertex of
    Nothing -> pure Nothing
    Just vertex -> do
      mFragment <- compileShader gl glFragmentShader fragmentSource (label <> " fragment")
      case mFragment of
        Nothing -> do
          void $ gl # "deleteShader" $ [vertex]
          pure Nothing
        Just fragment -> do
          program <- gl # "createProgram" $ ()
          absent <- isAbsent program
          if absent
            then do
              void $ gl # "deleteShader" $ [vertex]
              void $ gl # "deleteShader" $ [fragment]
              pure Nothing
            else do
              void $ gl # "attachShader" $ (program, vertex)
              void $ gl # "attachShader" $ (program, fragment)
              void $ gl # "linkProgram" $ [program]
              linked <- getParameterBool gl "getProgramParameter" program glLinkStatus
              if linked
                then pure (Just (GlProgram program vertex fragment))
                else do
                  info <- gl # "getProgramInfoLog" $ [program]
                  detail <- fromJSValUnchecked info :: IO MisoString
                  logError (label <> " program failed to link") detail
                  void $ gl # "deleteProgram" $ [program]
                  void $ gl # "deleteShader" $ [vertex]
                  void $ gl # "deleteShader" $ [fragment]
                  pure Nothing
-----------------------------------------------------------------------------
compileShader :: JSVal -> Int -> MisoString -> MisoString -> IO (Maybe JSVal)
compileShader gl shaderType source label = do
  shader <- gl # "createShader" $ [shaderType]
  absent <- isAbsent shader
  if absent
    then pure Nothing
    else do
      void $ gl # "shaderSource" $ (shader, source)
      void $ gl # "compileShader" $ [shader]
      compiled <- getParameterBool gl "getShaderParameter" shader glCompileStatus
      if compiled
        then pure (Just shader)
        else do
          info <- gl # "getShaderInfoLog" $ [shader]
          detail <- fromJSValUnchecked info :: IO MisoString
          logError (label <> " shader failed to compile") detail
          void $ gl # "deleteShader" $ [shader]
          pure Nothing
-----------------------------------------------------------------------------
deleteProgram :: JSVal -> GlProgram -> IO ()
deleteProgram gl program = do
  void $ gl # "deleteProgram" $ [glProgram program]
  void $ gl # "deleteShader" $ [glVertex program]
  void $ gl # "deleteShader" $ [glFragment program]
-----------------------------------------------------------------------------
-- | Deleting resources does not free a context, and every mount creates one.
-- Release it so the page stays under the browser's live-context cap.
releaseContext :: JSVal -> IO ()
releaseContext gl = do
  lost <- isContextLost gl
  unless lost $ do
    extension <- gl # "getExtension" $ ("WEBGL_lose_context" :: MisoString)
    absent <- isAbsent extension
    unless absent $ void $ extension # "loseContext" $ ()
-----------------------------------------------------------------------------
-- | @texImage2D@ with a null pixel pointer, which allocates a blank texture.
-- The nine-argument call exceeds 'Miso.DSL.ToArgs' tuple support, so the
-- arguments are marshalled as a spread list.
texImage2DNull
  :: JSVal
  -> Int
  -- ^ target
  -> Int
  -- ^ level
  -> Int
  -- ^ internal format
  -> Int
  -- ^ width
  -> Int
  -- ^ height
  -> Int
  -- ^ border
  -> Int
  -- ^ format
  -> Int
  -- ^ type
  -> IO ()
texImage2DNull gl target level internalFormat width height border format pixelType =
  texImage2DWith gl target level internalFormat width height border format pixelType jsNull
-----------------------------------------------------------------------------
-- | @texImage2D@ with an explicit pixel source: a typed array for one-pixel
-- initialization, or an image element for an upload.
texImage2DWith
  :: JSVal
  -> Int
  -> Int
  -> Int
  -> Int
  -> Int
  -> Int
  -> Int
  -> Int
  -> JSVal
  -> IO ()
texImage2DWith gl target level internalFormat width height border format pixelType pixels = do
  arguments <- mapM toJSVal [target, level, internalFormat, width, height, border, format, pixelType]
  void $ gl # "texImage2D" $ (arguments ++ [pixels])
-----------------------------------------------------------------------------
isContextLost :: JSVal -> IO Bool
isContextLost gl = do
  value <- gl # "isContextLost" $ ()
  fromJSValUnchecked value
-----------------------------------------------------------------------------
getParameterBool :: JSVal -> MisoString -> JSVal -> Int -> IO Bool
getParameterBool gl method object parameter = do
  value <- gl # method $ (object, parameter)
  fromJSValUnchecked value
-----------------------------------------------------------------------------
getParameterInt :: JSVal -> MisoString -> JSVal -> Int -> IO Int
getParameterInt gl method object parameter = do
  value <- gl # method $ (object, parameter)
  fromJSValUnchecked value
-----------------------------------------------------------------------------
-- | Read @object[key]@ as a number.
number :: JSVal -> MisoString -> IO Double
number object key = fromJSValUnchecked =<< object ! key
-----------------------------------------------------------------------------
-- | Read @object[key]@ as an integer.
int :: JSVal -> MisoString -> IO Int
int object key = fromJSValUnchecked =<< object ! key
-----------------------------------------------------------------------------
-- | @performance.now()@, the time base @requestAnimationFrame@ hands back.
performanceNow :: IO Double
performanceNow = do
  performance <- jsg "performance"
  value <- performance # "now" $ ()
  fromJSValUnchecked value
-----------------------------------------------------------------------------
-- | Own each successful acquisition before attempting the next. MaybeT
-- handles ordinary failure; the enclosing scope handles rollback and teardown.
acquire :: Browser.Scope -> IO (Maybe a) -> (a -> IO ()) -> MaybeT IO a
acquire scope createResource release = do
  resource <- MaybeT createResource
  lift (Browser.own scope (release resource))
  pure resource

optionalObject :: IO JSVal -> IO (Maybe JSVal)
optionalObject action = do
  value <- action
  absent <- isAbsent value
  pure (if absent then Nothing else Just value)

uniformLocation :: JSVal -> GlProgram -> MisoString -> IO JSVal
uniformLocation gl program name = gl # "getUniformLocation" $ (glProgram program, name)

attribLocation :: JSVal -> GlProgram -> MisoString -> IO Int
attribLocation gl program name = fromJSValUnchecked =<< (gl # "getAttribLocation" $ (glProgram program, name))
-----------------------------------------------------------------------------
logError :: MisoString -> MisoString -> IO ()
logError label detail = do
  console <- jsg "console"
  void $ console # "error" $ (label, detail)
-----------------------------------------------------------------------------
glVertexShader, glFragmentShader, glCompileStatus, glLinkStatus :: Int
glVertexShader = 0x8B31
glFragmentShader = 0x8B30
glCompileStatus = 0x8B81
glLinkStatus = 0x8B82

glTriangles :: Int
glTriangles = 0x0004

glTriangleStrip :: Int
glTriangleStrip = 0x0005

glTexture2D, glTexture0, glLinear, glClampToEdge :: Int
glTexture2D = 0x0DE1
glTexture0 = 0x84C0
glLinear = 0x2601
glClampToEdge = 0x812F

glNearest, glLuminance :: Int
glNearest = 0x2600
glLuminance = 0x1909

glTextureMagFilter, glTextureMinFilter, glTextureWrapS, glTextureWrapT :: Int
glTextureMagFilter = 0x2800
glTextureMinFilter = 0x2801
glTextureWrapS = 0x2802
glTextureWrapT = 0x2803

glRgba, glRgba8, glUnsignedByte :: Int
glRgba = 0x1908
glRgba8 = 0x8058
glUnsignedByte = 0x1401

glFramebuffer, glColorAttachment0, glFramebufferComplete :: Int
glFramebuffer = 0x8D40
glColorAttachment0 = 0x8CE0
glFramebufferComplete = 0x8CD5

-- The WebGL1 vertex/texture state the hollow mark uses.
glArrayBuffer, glStaticDraw, glFloat, glDepthTest, glLequal, glCullFace :: Int
glArrayBuffer = 0x8892
glStaticDraw = 0x88E4
glFloat = 0x1406
glDepthTest = 0x0B71
glLequal = 0x0203
glCullFace = 0x0B44

glTexture2, glRepeat, glUnpackFlipY :: Int
glTexture2 = 0x84C2
glRepeat = 0x2901
glUnpackFlipY = 0x9240

glTexture1 :: Int
glTexture1 = 0x84C1

-- | @COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT@: the two buffers the mark clears.
glColorDepthBits :: Int
glColorDepthBits = 0x4000 + 0x0100
