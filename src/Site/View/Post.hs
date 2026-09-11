-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | One post: cover, title and date, the structured body, the reading rail,
-- the action bar, and the previous/next cards. Ported from the source's
-- @Page.Post@; the body itself is rendered by 'Site.Prose'.
module Site.View.Post
  ( postView
  ) where
-----------------------------------------------------------------------------
import           Data.Char (toLower)
import           Data.List (isSuffixOf)
import           Miso (text)
import qualified Miso.CSS as CSS
import           Miso.Event
  ( Decoder
  , Options (..)
  , Phase (BUBBLE)
  , at
  , defaultOptions
  , onWithOptions
  )
import           Miso.Html.Element as H
import           Miso.Html.Event as E
import           Miso.Html.Property as P
import           Miso.JSON (withObject, (.:))
import           Miso.Property (textProp)
import           Miso.String (MisoString, fromMisoString, ms)
-----------------------------------------------------------------------------
import           Site.Action (Action (..))
import qualified Site.Config as Config
import           Site.Content (Post)
import qualified Site.Content as Content
import           Site.Model (CopyStatus (..))
import qualified Site.Prose as Prose
import           Site.Route (Route (..))
import qualified Site.Route as Route
import           Site.Scroll (HeadingPosition (..), ReadingProgress (..))
import           Site.View.Icons
  ( chainLinkIcon
  , checkIcon
  , homeArrowIcon
  )
import           Site.View.Link (Node, internalLink)
-----------------------------------------------------------------------------
postView :: Post -> CopyStatus -> ReadingProgress -> Node context
postView post status progress =
  H.div_
    [ P.data_ "post-layout" "true"
    , P.class_ "post-layout relative w-full"
    ]
    (rail <> [ article ])
  where
    rail
      | null (Content.postToc post) = []
      | otherwise = [ readingRail progress ]
    article =
      H.article_
        [ P.class_ "min-w-0 space-y-6" ]
        ( cover post
          <> [ titleRow post
             , H.div_
                 [ P.class_ (Config.postProseClass <> " prose prose-neutral dark:prose-invert max-w-none prose-headings:font-instrument") ]
                 (Prose.renderBlocks (Content.postBody post))
             , actionBar post status
             ]
          <> postNavigation post
        )
-----------------------------------------------------------------------------
titleRow :: Post -> Node context
titleRow post =
  H.div_
    [ P.class_ "flex w-full min-w-0 items-center gap-3 text-[12px] leading-[1.7]" ]
    [ H.h1_
        [ P.class_ "min-w-0 font-instrument text-2xl leading-tight text-balance text-ink dark:text-neutral-100" ]
        [ text (Content.postTitle post) ]
    , H.span_
        [ P.class_ "min-h-px min-w-6 flex-1 border-b border-neutral-300 dark:border-neutral-600" ]
        []
    , H.span_
        [ P.class_ "shrink-0 text-right text-neutral-600 dark:text-neutral-400" ]
        [ text (Content.postDateLabel post) ]
    ]
-----------------------------------------------------------------------------
cover :: Post -> [Node context]
cover post
  | Content.postBanner post == "" = []
  | isNativeMedia banner = [ nativeCover post banner ]
  | otherwise = [ ditheredCover post banner ]
  where
    banner = Content.postBanner post
-----------------------------------------------------------------------------
nativeCover :: Post -> MisoString -> Node context
nativeCover post banner =
  H.div_
    [ P.class_ "post-cover overflow-hidden rounded-lg" ]
    [ if isMp4 banner
        then H.video_
          [ P.src_ banner
          , textProp "autoplay" "true"
          , textProp "muted" "true"
          , textProp "loop" "true"
          , textProp "playsinline" "true"
          , P.preload_ "metadata"
          , textProp "aria-label" (Content.postTitle post)
          , P.class_ "post-cover-media"
          ]
          []
        else H.img_
          [ P.src_ banner
          , textProp "alt" (Content.postTitle post)
          , textProp "loading" "eager"
          , P.class_ "post-cover-media"
          ]
    ]
-----------------------------------------------------------------------------
-- | The dithered cover markup. The widget raises @data-dither-fallback@
-- itself when WebGL is missing, which is what keeps the source image
-- visible; a mounted canvas replaces the plain image.
ditheredCover :: Post -> MisoString -> Node context
ditheredCover post banner =
  H.div_
    [ P.class_ "dithered-image relative overflow-hidden post-cover rounded-lg"
    , P.data_ Config.ditheredImageKey ""
    ]
    [ H.img_
        [ P.src_ banner
        , textProp "alt" (Content.postTitle post)
        , P.data_ Config.ditheredSourceKey ""
        , textProp "loading" "eager"
        , P.class_ "dithered-image-source absolute inset-0 h-full w-full object-cover"
        ]
    , H.canvas_
        [ P.aria_ "hidden" "true"
        , P.data_ Config.ditheredCanvasKey ""
        , P.class_ "cover-canvas block h-full w-full"
        ]
        []
    ]
-----------------------------------------------------------------------------
isNativeMedia :: MisoString -> Bool
isNativeMedia source = isMp4 source || isGif source
-----------------------------------------------------------------------------
-- | Only the path decides the media type, matching the content generator:
-- a query or fragment cannot turn an image URL into an MP4.
mediaPath :: MisoString -> String
mediaPath = map toLower . takeWhile (`notElem` ("?#" :: String)) . fromMisoString
-----------------------------------------------------------------------------
isMp4 :: MisoString -> Bool
isMp4 source = ".mp4" `isSuffixOf` mediaPath source
-----------------------------------------------------------------------------
isGif :: MisoString -> Bool
isGif source = ".gif" `isSuffixOf` mediaPath source
-----------------------------------------------------------------------------
readingRail :: ReadingProgress -> Node context
readingRail progress =
  H.aside_
    [ P.class_ "absolute inset-y-0 right-[calc((100%-100vw)/2+0.25rem)] z-20 w-2.5 lg:right-[calc((100%-100vw)/2+2rem)] lg:w-4" ]
    [ H.div_
        [ P.class_ "sticky top-32 h-[calc(100vh-16rem)] w-2.5 lg:w-4" ]
        (map tick [0 .. 99] <> [ bottomTick, progressSlider progress, progressHandle progress ])
    ]
  where
    headings = readingHeadings progress
    tick value =
      H.span_
        [ P.aria_ "hidden" "true"
        , P.data_ "reading-progress-tick" (ms value)
        , P.class_ "group absolute right-0 z-30 h-[1%] w-16 cursor-pointer lg:w-20"
        , CSS.style_ [("top", ms value <> "%")]
        , E.onClick (SelectedReadingProgress value)
        ]
        [ H.span_ [ P.class_ (tickMarkerClass headings value <> " top-0") ] [] ]
    bottomTick =
      H.span_
        [ P.aria_ "hidden" "true"
        , P.data_ "reading-progress-tick" "100"
        , P.class_ "group absolute right-0 z-30 h-[1%] w-16 cursor-pointer lg:w-20"
        , CSS.style_ [("bottom", "0px")]
        , E.onClick (SelectedReadingProgress 100)
        ]
        [ H.span_ [ P.class_ (tickMarkerClass headings 100 <> " bottom-0") ] [] ]
-----------------------------------------------------------------------------
tickMarkerClass :: [HeadingPosition] -> Int -> MisoString
tickMarkerClass headings value = case filter ((== value) . posProgress) headings of
  [] -> baseTickClass
  (heading : _) -> headingTickClass (posLevel heading)
-----------------------------------------------------------------------------
baseTickClass :: MisoString
baseTickClass =
  "absolute right-0 h-px w-3 origin-right scale-x-[0.375] bg-neutral-300 transition-[scale,background-color] duration-150 ease-out motion-reduce:transition-none group-hover:scale-x-100 group-hover:bg-neutral-600 dark:bg-gray-800 dark:group-hover:bg-gray-500 lg:w-5"
-----------------------------------------------------------------------------
headingTickClass :: Int -> MisoString
headingTickClass level =
  "absolute right-0 h-px w-3 origin-right transition-[scale,background-color] duration-150 ease-out motion-reduce:transition-none group-hover:scale-x-100 group-hover:bg-neutral-600 dark:group-hover:bg-gray-500 lg:w-5 "
    <> headingScale level
-----------------------------------------------------------------------------
headingScale :: Int -> MisoString
headingScale = \case
  2 -> "scale-x-100 bg-neutral-500 dark:bg-gray-600"
  3 -> "scale-x-[0.875] bg-neutral-500/85 dark:bg-gray-600/85"
  4 -> "scale-x-75 bg-neutral-500/70 dark:bg-gray-600/70"
  _ -> "scale-x-[0.625] bg-neutral-500/55 dark:bg-gray-600/55"
-----------------------------------------------------------------------------
progressSlider :: ReadingProgress -> Node context
progressSlider progress =
  H.div_
    [ textProp "aria-label" "Reading progress"
    , textProp "aria-orientation" "vertical"
    , textProp "aria-valuemax" "100"
    , textProp "aria-valuemin" "0"
    , textProp "aria-valuenow" (ms (readingPercent progress))
    , textProp "aria-valuetext" (ms (readingPercent progress) <> "% read")
    , P.class_ "peer absolute inset-y-0 -right-2 z-20 w-16 cursor-pointer touch-manipulation outline-none"
    , P.role_ "slider"
    , P.tabindex_ "0"
    , onWithOptions BUBBLE preventDefaultOptions "keydown" keyDecoder (\key _ _ -> progressKey key)
    ]
    []
-----------------------------------------------------------------------------
preventDefaultOptions :: Options
preventDefaultOptions = defaultOptions { _preventDefault = True }
-----------------------------------------------------------------------------
keyDecoder :: Decoder MisoString
keyDecoder = at [] $ withObject "keydown" $ \object -> object .: "key"
-----------------------------------------------------------------------------
progressKey :: MisoString -> Action
progressKey = \case
  "ArrowUp"    -> AdjustedReadingProgress (-5)
  "ArrowLeft"  -> AdjustedReadingProgress (-5)
  "ArrowDown"  -> AdjustedReadingProgress 5
  "ArrowRight" -> AdjustedReadingProgress 5
  "PageUp"     -> AdjustedReadingProgress (-10)
  "PageDown"   -> AdjustedReadingProgress 10
  "Home"       -> SelectedReadingProgress 0
  "End"        -> SelectedReadingProgress 100
  _            -> IgnoredKey
-----------------------------------------------------------------------------
progressHandle :: ReadingProgress -> Node context
progressHandle progress =
  H.span_
    [ P.aria_ "hidden" "true"
    , P.class_ "pointer-events-none absolute right-0 z-40 h-px w-3 peer-focus-visible:outline-1 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-orange-500 peer-focus-visible:outline-dashed lg:w-5"
    , CSS.style_ [("top", ms (readingPercent progress) <> "%")]
    ]
    [ H.span_
        [ P.class_ "absolute top-1/2 right-6 hidden -translate-y-1/2 lg:block" ]
        [ H.span_
            [ P.class_ "font-mono text-xs leading-none text-orange-500 tabular-nums" ]
            [ text (ms (readingPercent progress) <> "%") ]
        ]
    , H.span_
        [ P.class_ "absolute inset-0 origin-right bg-orange-500" ]
        []
    ]
-----------------------------------------------------------------------------
actionBar :: Post -> CopyStatus -> Node context
actionBar post status =
  H.div_
    [ P.class_ "post-action-bar" ]
    [ internalLink (Section (Content.postSection post))
        [ textProp "aria-label" "Back to section"
        , P.title_ "Back to section"
        , P.class_ "post-action-button"
        ]
        [ homeArrowIcon ]
    , H.button_
        [ P.type_ "button"
        , E.onClick (ClickedCopyLink canonical)
        , textProp "aria-label" (copyAriaLabel status)
        , P.title_ (copyTitle status)
        , P.class_ "post-action-button"
        ]
        [ copyIcon status ]
    ]
  where
    canonical =
      Config.siteUrl <> Route.routePath (Post (Content.postSection post) (Content.postSlug post))
-----------------------------------------------------------------------------
copyAriaLabel :: CopyStatus -> MisoString
copyAriaLabel = \case
  NotCopied -> "Copy link to clipboard"
  Copied    -> "Link copied"
-----------------------------------------------------------------------------
copyTitle :: CopyStatus -> MisoString
copyTitle = \case
  NotCopied -> "Copy link"
  Copied    -> "Copied"
-----------------------------------------------------------------------------
copyIcon :: CopyStatus -> Node context
copyIcon = \case
  NotCopied -> chainLinkIcon
  Copied    -> checkIcon
-----------------------------------------------------------------------------
postNavigation :: Post -> [Node context]
postNavigation post
  | older == Nothing && newer == Nothing = []
  | otherwise =
      [ H.nav_
          [ textProp "aria-label" "Post navigation"
          , P.class_ "mt-12 grid grid-cols-2 gap-3 border-t border-hairline pt-6 dark:border-neutral-800"
          ]
          [ maybe (H.span_ [] []) (link False) older
          , maybe (H.span_ [] []) (link True) newer
          ]
      ]
  where
    (older, newer) = Content.neighboringPosts post
    link right neighbor =
      internalLink (Post (Content.postSection neighbor) (Content.postSlug neighbor))
        [ P.class_
            ( "group flex flex-col gap-1 rounded-md border border-hairline px-4 py-3 no-underline transition-colors hover:border-coral dark:border-neutral-800 "
                <> if right then "items-end text-right" else "items-start text-left"
            )
        ]
        [ H.span_
            [ P.class_ "text-[10px] uppercase tracking-[0.07em] text-neutral-600 dark:text-neutral-400" ]
            [ text (if right then "Newer" else "Older") ]
        , H.span_
            [ P.class_ "font-instrument text-[15px] leading-snug text-ink group-hover:text-coral dark:text-neutral-200 dark:group-hover:text-coral-bright" ]
            [ text (Content.postTitle neighbor) ]
        ]
