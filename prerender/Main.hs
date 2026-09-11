-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | Static site generator.
--
-- Renders every route in 'Site.Meta.prerenderRoutes' to
-- @public/&lt;path&gt;/index.html@ with 'Miso.Html.Render.toHtml', using the
-- shared application views, and writes @404.html@, @sitemap.xml@ and
-- @robots.txt@ from the same 'Site.Meta' catalog.
--
-- Built with vanilla GHC and miso's @ssr@ flag (see @cabal.project@); the
-- WASM build never compiles this executable. Run it *after* @make build@,
-- which replaces @public/@ from @static/@.
module Main (main) where
-----------------------------------------------------------------------------
import           Control.Monad (forM_)
import           Data.Bits (xor)
import qualified Data.ByteString.Lazy as BL
import           Data.Word (Word64)
import           Numeric (showHex)
import           System.Directory (createDirectoryIfMissing, doesFileExist)
import           System.FilePath (takeDirectory)
-----------------------------------------------------------------------------
import           Miso.Html.Render (toHtml)
import           Miso.String (MisoString)
import qualified Miso.String as MS
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import           Site.Document (documentView)
import qualified Site.Meta as Meta
import           Site.Route (Route (..))
import qualified Site.Route as Route
-----------------------------------------------------------------------------
main :: IO ()
main = do
  version <- buildVersion
  putStrLn ("Asset version: " <> MS.unpack version)
  forM_ pages $ \(route, meta) -> do
    let path = outputPath route
    writeUtf8 path (toHtml (documentView version route meta))
    putStrLn ("  " <> path)
  let missing = NotFound "/404"
  writeUtf8 "public/404.html"
    (toHtml (documentView version missing (Meta.metaForRoute missing)))
  writeText "public/sitemap.xml" sitemap
  writeText "public/robots.txt" robots
  putStrLn
    ( "Prerendered "
    <> show (length pages + 1)
    <> " page(s), plus sitemap.xml and robots.txt."
    )
  where
    pages =
      [ (route, Meta.metaForRoute route) | route <- Meta.prerenderRoutes ]
-----------------------------------------------------------------------------
-- | Cache-busting stamp appended to the stylesheet and loader URLs as
-- @?v=…@. A content hash of @public/app.wasm@ (or @public/index.js@ on the
-- JS host), so the HTML, loader, FFI glue and WASM of one deploy always load
-- together instead of mixing cached and fresh versions. Run after
-- @make optim@ so the final WASM is what gets hashed.
buildVersion :: IO MisoString
buildVersion = go [ "public/app.wasm", "public/index.js" ]
  where
    go [] = pure "dev"
    go (file : files) = do
      exists <- doesFileExist file
      if exists
        then MS.pack . flip showHex "" . fnv1a <$> BL.readFile file
        else go files
    -- FNV-1a: tiny, dependency-free; only needs to change between builds.
    fnv1a :: BL.ByteString -> Word64
    fnv1a = BL.foldl' step 0xcbf29ce484222325
      where
        step hash byte = (hash `xor` fromIntegral byte) * 0x100000001b3
-----------------------------------------------------------------------------
-- | @/thought/@ becomes @public/thought/index.html@; the root becomes
-- @public/index.html@.
outputPath :: Route -> FilePath
outputPath route =
  case dropWhile (== '/') (MS.unpack (Route.routePath route)) of
    ""   -> "public/index.html"
    rest -> "public/" <> rest <> "index.html"
-----------------------------------------------------------------------------
sitemap :: String
sitemap = unlines $
  [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  , "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"
  ]
  <> [ "  <url><loc>" <> url route <> "</loc></url>"
     | route <- Meta.prerenderRoutes
     ]
  <> [ "</urlset>" ]
  where
    url = MS.unpack . Meta.canonicalForRoute
-----------------------------------------------------------------------------
robots :: String
robots = unlines
  [ "User-agent: *"
  , "Allow: /"
  , "Sitemap: " <> MS.unpack Config.siteUrl <> "/sitemap.xml"
  ]
-----------------------------------------------------------------------------
writeUtf8 :: FilePath -> BL.ByteString -> IO ()
writeUtf8 path bytes = do
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path bytes
-----------------------------------------------------------------------------
writeText :: FilePath -> String -> IO ()
writeText path contents = do
  createDirectoryIfMissing True (takeDirectory path)
  writeFile path contents
