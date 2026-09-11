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
