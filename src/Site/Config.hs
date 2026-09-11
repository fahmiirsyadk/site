-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | Site-wide constants. Everything here is data, not behaviour, so the
-- native prerender generator and the WASM client read identical values.
module Site.Config
  ( -- * Identity
    siteName
  , siteUrl
  , siteHost
  , brandMark
  , emailAddress
  , siteDescription
  , defaultSocialImage
    -- * GitHub
  , githubUsername
  , githubProfileUrl
  , githubAvatarUrl
  , githubDisplayName
  , githubLocation
    -- * Content sections
  , thoughtSection
  , labSection
  , contentSections
    -- * DOM contract
    -- $domcontract
  , contentScrollId
  , contentScrollSelector
  , pageViewId
  , seaFooterId
  , seaCanvasId
  , routeMotionKey
  , postProseClass
  , postProseSelector
  , postHeadingSelector
  , hollowMarkClass
  , hollowMarkSelector
  , hollowDraggingKey
  , scribbleKey
  , scribblePathKey
  , scribbleSelector
  , scribblePathSelector
  , labInteractionKey
  , labInteractionHovered
  , labInteractionIdle
  , ditheredImageKey
  , ditheredSourceKey
  , ditheredCanvasKey
  , ditheredImageSelector
  , ditheredSourceSelector
  , ditheredCanvasSelector
  , ditherInitializedKey
  , ditherReadyKey
  , ditherFallbackKey
  , internalLinkKey
  , internalLinkSelector
  , internalLinkGuardProperty
    -- * Theme contract
  , darkClassName
  , prefersDarkQuery
    -- * Storage
  , themeStorageKey
    -- * Route transition timing
  , routeLeaveMs
  , routeEntryMs
  ) where
-----------------------------------------------------------------------------
import    Miso.String (MisoString)
-----------------------------------------------------------------------------
siteName :: MisoString
siteName = "Faah"
-----------------------------------------------------------------------------
siteUrl :: MisoString
siteUrl = "https://faah.me"
-----------------------------------------------------------------------------
siteHost :: MisoString
siteHost = "faah.me"
-----------------------------------------------------------------------------
-- | Wordmark in the header.
brandMark :: MisoString
brandMark = "Fa—h"
-----------------------------------------------------------------------------
emailAddress :: MisoString
emailAddress = "hello@faah.me"
-----------------------------------------------------------------------------
-- | Site-wide meta description, and the social image used when a route does
-- not name its own. The image path is relative; 'Site.Meta' makes it absolute.
siteDescription :: MisoString
siteDescription = "Notes on systems, software, and the long arc of building things that last."
-----------------------------------------------------------------------------
defaultSocialImage :: MisoString
defaultSocialImage = "/assets/banners/pendulum.png"
-----------------------------------------------------------------------------
-- | The GitHub identity on the home card. The API URLs live in 'Site.GitHub'.
githubUsername :: MisoString
githubUsername = "fahmiirsyadk"
-----------------------------------------------------------------------------
githubProfileUrl :: MisoString
githubProfileUrl = "https://github.com/" <> githubUsername
-----------------------------------------------------------------------------
githubAvatarUrl :: MisoString
githubAvatarUrl = "https://avatars.githubusercontent.com/u/17546686?v=4"
-----------------------------------------------------------------------------
githubDisplayName :: MisoString
githubDisplayName = "fa-h"
-----------------------------------------------------------------------------
githubLocation :: MisoString
githubLocation = "Indonesia"
-----------------------------------------------------------------------------
thoughtSection :: MisoString
thoughtSection = "thought"
-----------------------------------------------------------------------------
labSection :: MisoString
labSection = "lab"
-----------------------------------------------------------------------------
-- | The only path segments that name a content section. A single-segment path
-- outside this list is a 404, not an empty section.
contentSections :: [MisoString]
contentSections = [ thoughtSection, labSection ]
-----------------------------------------------------------------------------
-- $domcontract
-- These ids are shared with the Haskell widget mounts and with @styles.css@.
-- They are named here so the view and the effects that reach into the DOM
-- cannot drift apart.
-----------------------------------------------------------------------------
contentScrollId :: MisoString
contentScrollId = "content-scroll"
-----------------------------------------------------------------------------
contentScrollSelector :: MisoString
contentScrollSelector = "#" <> contentScrollId
-----------------------------------------------------------------------------
pageViewId :: MisoString
pageViewId = "page-view"
-----------------------------------------------------------------------------
seaFooterId :: MisoString
seaFooterId = "sea-footer"
-----------------------------------------------------------------------------
seaCanvasId :: MisoString
seaCanvasId = "sea-canvas"
-----------------------------------------------------------------------------
-- | Value of the @data-route-motion@ attribute. The three @.route-content@
-- rules in @styles.css@ select on it.
routeMotionKey :: MisoString
routeMotionKey = "route-motion"
-----------------------------------------------------------------------------
-- | The post body. The view writes the class, the reading rail discovers
-- headings inside it, and @styles.css@ styles it.
postProseClass :: MisoString
postProseClass = "post-prose"
-----------------------------------------------------------------------------
postProseSelector :: MisoString
postProseSelector = "." <> postProseClass
-----------------------------------------------------------------------------
-- | Headings the reading rail anchors to. The prose renderer only emits these
-- three levels.
postHeadingSelector :: MisoString
postHeadingSelector = "h2, h3, h4"
-----------------------------------------------------------------------------
-- | The header's WebGL mark. The view writes the class, the widget queries it.
hollowMarkClass :: MisoString
hollowMarkClass = "hollow-mark"
-----------------------------------------------------------------------------
hollowMarkSelector :: MisoString
hollowMarkSelector = "." <> hollowMarkClass
-----------------------------------------------------------------------------
-- | Set to @true@ while the mark is dragged; @styles.css@ selects on it.
hollowDraggingKey :: MisoString
hollowDraggingKey = "dragging"
-----------------------------------------------------------------------------
-- | The home page's animated scribble and the path inside it.
scribbleKey :: MisoString
scribbleKey = "random-scribble"
-----------------------------------------------------------------------------
scribblePathKey :: MisoString
scribblePathKey = "random-scribble-path"
-----------------------------------------------------------------------------
scribbleSelector, scribblePathSelector :: MisoString
scribbleSelector = "[data-" <> scribbleKey <> "]"
scribblePathSelector = "[data-" <> scribblePathKey <> "]"
-----------------------------------------------------------------------------
-- | Drives the sea footer's and hollow mark's hover state. The values are
-- produced by 'Site.Model.labInteractionName'.
labInteractionKey :: MisoString
labInteractionKey = "lab-interaction"
-----------------------------------------------------------------------------
labInteractionHovered :: MisoString
labInteractionHovered = "hovered"
-----------------------------------------------------------------------------
labInteractionIdle :: MisoString
labInteractionIdle = "idle"
-----------------------------------------------------------------------------
-- | Dithered-image markup. 'Site.Prose' and 'Site.View.Post' write the three
-- keys; the widget queries the selectors and raises the state keys.
ditheredImageKey, ditheredSourceKey, ditheredCanvasKey :: MisoString
ditheredImageKey = "dithered-image"
ditheredSourceKey = "dithered-source"
ditheredCanvasKey = "dithered-canvas"
-----------------------------------------------------------------------------
ditheredImageSelector, ditheredSourceSelector, ditheredCanvasSelector :: MisoString
ditheredImageSelector = "[data-" <> ditheredImageKey <> "]"
ditheredSourceSelector = "img[data-" <> ditheredSourceKey <> "]"
ditheredCanvasSelector = "canvas[data-" <> ditheredCanvasKey <> "]"
-----------------------------------------------------------------------------
-- | State the widget writes back on a root: mounted, first frame drawn, and
-- WebGL unavailable. @styles.css@ selects on the last two.
ditherInitializedKey, ditherReadyKey, ditherFallbackKey :: MisoString
ditherInitializedKey = "dither-initialized"
ditherReadyKey = "dither-ready"
ditherFallbackKey = "dither-fallback"
-----------------------------------------------------------------------------
-- | Internal links carry the marker the synchronous click guard looks for.
internalLinkKey :: MisoString
internalLinkKey = "internal-link"
-----------------------------------------------------------------------------
internalLinkSelector :: MisoString
internalLinkSelector = "a[data-" <> internalLinkKey <> "]"
-----------------------------------------------------------------------------
-- | Window property holding the installed guard callback, so a hot reload
-- replaces it instead of stacking listeners.
internalLinkGuardProperty :: MisoString
internalLinkGuardProperty = "__siteMisoInternalLinkGuard"
-----------------------------------------------------------------------------
-- | Class on @<html>@ that switches the theme, and the query that picks the
-- system preference. The anti-flash script reads both before WASM loads.
darkClassName :: MisoString
darkClassName = "dark"
-----------------------------------------------------------------------------
prefersDarkQuery :: MisoString
prefersDarkQuery = "(prefers-color-scheme: dark)"
-----------------------------------------------------------------------------
-- | @localStorage@ key. Read by the anti-flash script in @index.html@ before
-- the WASM module loads, so it must match that script exactly.
themeStorageKey :: MisoString
themeStorageKey = "theme"
-----------------------------------------------------------------------------
-- | How long the outgoing page is allowed to animate out before the URL
-- changes. Must match the @leaving@ transition-duration in @styles.css@.
routeLeaveMs :: Int
routeLeaveMs = 250
-----------------------------------------------------------------------------
-- | Delay between committing the incoming page and releasing it to @idle@.
--
-- Miso schedules its own draw on @requestAnimationFrame@, so the @entering@
-- state is not in the DOM the instant the model changes. Waiting two frames
-- is more reliable here than a @requestAnimationFrame@ of our own, which
-- would race Miso's render callback for position in the frame queue.
routeEntryMs :: Int
routeEntryMs = 32
-----------------------------------------------------------------------------
