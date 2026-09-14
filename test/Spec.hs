-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes        #-}
-----------------------------------------------------------------------------
-- | Native tests for the parts of the shell that hold still.
--
-- Two things are checked. The route table, exhaustively over a corpus of the
-- shapes the site actually serves plus the shapes that must fall through to
-- 'NotFound'; and the update function, by running it through
-- 'Miso.Effect.runEffect', which is 'Control.Monad.RWS.execRWS' and therefore
-- pure. Scheduled effects are counted, not performed -- no browser is
-- involved, which is the point.
module Main (main) where
-----------------------------------------------------------------------------
import           Control.Monad (forM_, unless)
import           Data.IORef (modifyIORef', newIORef, readIORef, writeIORef)
import           Data.List (isInfixOf, isPrefixOf)
import           Data.Maybe (listToMaybe)
import           Miso (URI (..))
import           Miso.DSL (jsNull)
import           Miso.Effect (mkComponentInfo, runEffect)
import           Miso.JSON (decode)
import           Miso.String (MisoString)
import qualified Miso.String as MS
import           System.Exit (exitFailure, exitSuccess)
-----------------------------------------------------------------------------
import           Site.Action (Action (..))
import qualified Site.Config as Config
import qualified Site.Content as Content
import qualified Site.Canvas as Canvas
import qualified Site.Dither as Dither
import           Site.Document (antiFlashScript)
import           Site.GitHub (Contributions (..), GitHubActivity (..), GitHubStatus (..), Profile (..))
import qualified Site.Hollow as Hollow
import qualified Site.HollowGeometry as HollowGeometry
import qualified Site.GitHub as GitHub
import           Site.Meta (Meta (..))
import qualified Site.Meta as Meta
import           Site.Model
                 ( CopyStatus (..)
                 , Model (..)
                  , Page (..)
                  , PostState (..)
                  , PostRequest (..)
                  , RouteMotion (..)
                  , navigationMotion
                  , pendingRoute
                 , labInteractionName
                 , modelFor
                 , motionName
                 )
import           Site.Prose (Block (..))
import           Site.Route (Route (..))
import qualified Site.Route as Route
import qualified Site.Section as Section
import           Site.Scroll
                 ( Geometry (..)
                 , HeadingGeometry (..)
                 , HeadingPosition (..)
                 , ReadingProgress (..)
                 )
import qualified Site.Scroll as Scroll
import qualified Site.Scribble as Scribble
import qualified Site.Sea as Sea
import qualified Site.FrameLoop as Frame
import           Site.Theme (Theme (..))
import qualified Site.Theme as Theme
import           Site.Update (updateModel)
import qualified Site.Widgets.Runtime as Widgets
-----------------------------------------------------------------------------
main :: IO ()
main = do
  widgets <- Widgets.newRuntime
  failures <- newIORef ([] :: [String])
  let
    check :: String -> Bool -> IO ()
    check label ok = unless ok (modifyIORef' failures (label :))

    checkEq :: (Eq a, Show a) => String -> a -> a -> IO ()
    checkEq label expected actual =
      check (label <> ": expected " <> show expected <> ", got " <> show actual)
            (expected == actual)

  routeSpec check checkEq
  updateSpec widgets check checkEq
  metaSpec check checkEq
  contentSpec check checkEq
  seaSpec check checkEq
  scrollSpec check checkEq
  gitHubSpec check checkEq
  scribbleSpec check checkEq
  hollowSpec check checkEq
  ditherSpec check checkEq
  frameLoopSpec check checkEq
  paletteSpec check

  collected <- reverse <$> readIORef failures
  case collected of
    [] -> putStrLn "all checks passed" >> exitSuccess
    _  -> do
      putStrLn (show (length collected) <> " failing check(s):")
      forM_ collected (putStrLn . ("  - " <>))
      exitFailure
-----------------------------------------------------------------------------
type Check = String -> Bool -> IO ()
type CheckEq = forall a. (Eq a, Show a) => String -> a -> a -> IO ()
-----------------------------------------------------------------------------
routeSpec :: Check -> CheckEq -> IO ()
routeSpec check checkEq = do

  -- Every path the site serves parses to the route it names.
  forM_ knownPaths $ \(path, expected) ->
    checkEq ("urlToRoute " <> show path) expected (Route.urlToRoute path)

  -- Printing is the inverse of parsing, on every route parsing can produce.
  forM_ (map snd knownPaths <> extraRoutes) $ \target ->
    checkEq ("round trip " <> show target) target
            (Route.urlToRoute (Route.routePath target))

  -- Parsing is idempotent on arbitrary input. This is the total law; the
  -- round trip above only holds for reachable routes.
  forM_ (map fst knownPaths <> messyPaths) $ \path -> do
    let once = Route.urlToRoute path
        twice = Route.urlToRoute (Route.routePath once)
    checkEq ("idempotent " <> show path) once twice

  -- prettyURI prepends the slash, so routeURI must not carry one.
  forM_ (map snd knownPaths <> extraRoutes) $ \target -> do
    let path = uriPath (Route.routeURI target)
    check ("routeURI has no leading slash: " <> show target)
          (MS.unpack path == dropWhile (== '/') (MS.unpack (Route.routePath target)))
    checkEq ("uriToRoute . routeURI " <> show target) target
            (Route.uriToRoute (Route.routeURI target))

  -- A single segment is a section only if it names one.
  check "thought is a content section" (Route.isContentSection "thought")
  check "lab is a content section" (Route.isContentSection "lab")
  check "ssh is not a content section" (not (Route.isContentSection "ssh"))

  checkEq "activeSection Home" Nothing (Route.activeSection Home)
  checkEq "activeSection Post" (Just Config.thoughtSection)
          (Route.activeSection (Post Config.thoughtSection "a-post"))
-----------------------------------------------------------------------------
knownPaths :: [(MisoString, Route)]
knownPaths =
  [ ("/", Home)
  , ("/ssh/", NotFound "/ssh")
   , ("/thought/", Section Section.Thought)
   , ("/lab/", Section Section.Lab)
   , ("/thought/a-post/", Post Section.Thought "a-post")
   , ("/lab/a-thing/", Post Section.Lab "a-thing")
  , ("/nope/", NotFound "/nope")
  , ("/nope/deeper/", NotFound "/nope/deeper")
  , ("/thought/a/b/", NotFound "/thought/a/b")
  ]
-----------------------------------------------------------------------------
-- | Reachable routes that no path in 'knownPaths' produces.
extraRoutes :: [Route]
extraRoutes =
  [ NotFound "/a"
  , NotFound "/a/b/c"
   , Post Section.Thought "slug-with-dashes"
  ]
-----------------------------------------------------------------------------
-- | Shapes a browser can hand us that are not canonical.
messyPaths :: [MisoString]
messyPaths =
  [ "", "ssh", "//", "/thought", "thought/a-post", "/thought//a-post//"
  , "/ssh", "/ssh//", "///a///b///"
  ]
-----------------------------------------------------------------------------
updateSpec :: Widgets.Runtime -> Check -> CheckEq -> IO ()
updateSpec widgets check checkEq = do
  let step = runStep widgets
      home = modelFor Home Light
      thought = Section Config.thoughtSection
      lab = Section Config.labSection

  -- Following a link marks the exit and schedules exactly one effect: the
  -- delay that returns NavigationReady. The page does not change yet.
  let (leaving, leavingEffects) = step home (FollowedLink thought)
  checkEq "FollowedLink sets Leaving" Leaving (_motion leaving)
  checkEq "FollowedLink leaves the page alone" HomePage (_page leaving)
  checkEq "FollowedLink schedules one effect" 1 leavingEffects

  -- Following a link to where we already are does nothing at all.
  let (same, sameEffects) = step home (FollowedLink Home)
  checkEq "FollowedLink to the current route is inert" home same
  checkEq "FollowedLink to the current route schedules nothing" 0 sameEffects

  -- A second intent replaces the first pending target. The first timer may
  -- still wake up, but its versioned completion is now inert.
  let (replacement, _) = step leaving (FollowedLink lab)
      (staleReady, staleEffects) = step replacement (NavigationReady 1 thought)
  checkEq "new link intent keeps the latest target pending" (Just lab) (_pendingNavigation replacement)
  checkEq "stale leave completion changes nothing" replacement staleReady
  checkEq "stale leave completion schedules nothing" 0 staleEffects
  let (committed, committedEffects) = step replacement (NavigationReady 2 lab)
  checkEq "current leave completion clears pending target" Nothing (_pendingNavigation committed)
  checkEq "current leave completion schedules one history write" 1 committedEffects

  -- Returning to the first target must not make its first timer current again.
  let (backToThought, _) = step replacement (FollowedLink thought)
      (obsoleteThought, obsoleteThoughtEffects) = step backToThought (NavigationReady 1 thought)
      (latestThought, latestThoughtEffects) = step backToThought (NavigationReady 3 thought)
  checkEq "ABA leaves the latest intent intact" backToThought obsoleteThought
  checkEq "ABA rejects the first target's old timer" 0 obsoleteThoughtEffects
  checkEq "ABA accepts the latest target's timer" Nothing (_pendingNavigation latestThought)
  checkEq "ABA commits only the latest intent" 1 latestThoughtEffects
  let (duplicateCommit, duplicateCommitEffects) = step committed (NavigationReady 2 lab)
  checkEq "repeated completion cannot push history twice" committed duplicateCommit
  checkEq "repeated completion schedules nothing" 0 duplicateCommitEffects

  -- Modified clicks must not cancel an ordinary navigation already pending.
  let (ignoredClick, ignoredEffects) = step leaving IgnoredLinkClick
  checkEq "modified click preserves pending navigation" leaving ignoredClick
  checkEq "modified click schedules nothing" 0 ignoredEffects

  -- A current-route click cancels a pending leave without changing the page.
  let (cancelledClick, cancelledClickEffects) = step leaving (FollowedLink Home)
  checkEq "current-route click cancels pending leave" Idle (_motion cancelledClick)
  checkEq "current-route click clears pending leave" Nothing (_pendingNavigation cancelledClick)
  checkEq "current-route click schedules nothing" 0 cancelledClickEffects

  -- History owns navigation even when its new URL names the current page.
  forM_ [Home, lab] $ \historyTarget -> do
    let (afterHistory, _) = step leaving (ChangedURI (Route.routeURI historyTarget))
        (afterOldTimer, oldTimerEffects) = step afterHistory (NavigationReady 1 thought)
    checkEq "history clears pending navigation" Nothing (_pendingNavigation afterHistory)
    checkEq "old leave timer cannot override history" afterHistory afterOldTimer
    checkEq "old leave timer cannot push history" 0 oldTimerEffects

  -- The URL change is what swaps the page.
  let (entering, enteringEffects) = step leaving (ChangedURI (Route.routeURI thought))
  checkEq "ChangedURI swaps the page" (SectionPage Config.thoughtSection) (_page entering)
  checkEq "ChangedURI sets Entering" Entering (_motion entering)
  checkEq "ChangedURI schedules one effect" 1 enteringEffects

  -- A previous entry cannot reveal the page during a newer exit animation.
  let (leavingAgain, _) = step entering (FollowedLink lab)
      (afterOldEntry, oldEntryEffects) = step leavingAgain (EnteredRoute 2)
  checkEq "old entry completion preserves newer leave" leavingAgain afterOldEntry
  checkEq "newer exit stays Leaving" Leaving (_motion afterOldEntry)
  checkEq "old entry completion schedules nothing" 0 oldEntryEffects

  -- A same-route history notification cancels an in-flight entry and makes
  -- the old entry completion stale.
  let (repeated, repeatedEffects) = step entering (ChangedURI (Route.routeURI thought))
  checkEq "same-route ChangedURI settles the current page" Idle (_motion repeated)
  checkEq "repeated ChangedURI schedules nothing" 0 repeatedEffects
  let (staleEntry, staleEntryEffects) = step repeated (EnteredRoute 2)
  checkEq "stale entry completion is inert" repeated staleEntry
  checkEq "stale entry completion schedules nothing" 0 staleEntryEffects

  -- And the entry completes.
  let (idle, idleEffects) = step entering (EnteredRoute 2)
  checkEq "EnteredRoute settles to Idle" Idle (_motion idle)
  checkEq "EnteredRoute schedules nothing" 0 idleEffects

  -- Back and forward buttons arrive without a FollowedLink first, and still
  -- swap the page.
  let (viaHistory, _) = step idle (ChangedURI (Route.routeURI Home))
  checkEq "history navigation swaps the page" HomePage (_page viaHistory)
  checkEq "history navigation still animates in" Entering (_motion viaHistory)

  -- Theme toggling is model plus one effect, never a page change.
  let (dark, darkEffects) = step home ToggledTheme
  checkEq "ToggledTheme flips the theme" Dark (_theme dark)
  checkEq "ToggledTheme leaves the page alone" HomePage (_page dark)
  checkEq "ToggledTheme schedules one effect" 1 darkEffects
  checkEq "ToggledTheme is an involution" Light (_theme (fst (step dark ToggledTheme)))

  -- The initial motion must be Idle: prerendered HTML is on screen before
  -- hydration, and the other two phases set opacity to zero.
  checkEq "boot is Idle" Idle (_motion home)

  -- The CSS selects on these exact strings.
  checkEq "motionName Idle" "idle" (motionName Idle)
  checkEq "motionName Leaving" "leaving" (motionName Leaving)
  checkEq "motionName Entering" "entering" (motionName Entering)

  -- The anti-flash script in index.html writes these values.
  checkEq "storageName Dark" "dark" (Theme.storageName Dark)
  checkEq "storageName Light" "light" (Theme.storageName Light)
  checkEq "parseStorageName round trips Dark" (Just Dark) (Theme.parseStorageName "dark")
  checkEq "parseStorageName rejects junk" Nothing (Theme.parseStorageName "purple")

  css <- readFile "styles/input.css"
  let leavingRule = takeWhile (/= '}') . drop 1 . dropWhile (/= '{') $
        dropUntil ".route-content[data-route-motion='leaving']" css
  check "leave duration matches the actual CSS transition"
        (contains ("transition-duration: " <> show Config.routeLeaveMs <> "ms;") leavingRule)

  -- The lab link's hover state drives the sea footer's data attribute.
  let (hoveredLab, hoveredLabEffects) = step home HoveredLab
      (leftLab, leftLabEffects) = step hoveredLab LeftLab
  check "HoveredLab raises the interaction" (_labHover hoveredLab)
  checkEq "HoveredLab schedules nothing" 0 hoveredLabEffects
  check "LeftLab lowers the interaction" (not (_labHover leftLab))
  checkEq "LeftLab schedules nothing" 0 leftLabEffects
  checkEq "the hover value is the configured name"
          Config.labInteractionHovered (labInteractionName hoveredLab)
  checkEq "elsewhere the interaction is idle"
          Config.labInteractionIdle (labInteractionName home)
  checkEq "being on the lab page counts as engagement"
          Config.labInteractionHovered (labInteractionName (modelFor lab Light))

  -- The copy button: success marks it and schedules the two-second reset.
  let postRoute = Post Section.Thought "chaotic-pendulum"
      post = modelFor postRoute Light
      (requested, _) = step post (ClickedCopyLink "https://faah.me/thought/chaotic-pendulum/")
      request = PostRequest 0 1
      (copied, copiedEffects) = step requested (CopiedLink request)
      (resetStatus, resetEffects) = step copied (CopyStatusExpired request)
  checkEq "CopiedLink marks the button" Copied (_copyStatus copied)
  checkEq "CopiedLink schedules the reset timer" 1 copiedEffects
  checkEq "CopyStatusExpired returns to idle" NotCopied (_copyStatus resetStatus)
  checkEq "CopyStatusExpired schedules nothing" 0 resetEffects

  let (requestedAgain, _) = step copied (ClickedCopyLink "url")
      (copiedAgain, _) = step requestedAgain (CopiedLink (PostRequest 0 2))
  checkEq "old expiry cannot clear a newer copy confirmation" copiedAgain
    (fst (step copiedAgain (CopyStatusExpired request)))
  checkEq "old clipboard completion cannot overwrite a newer request" requestedAgain
    (fst (step requestedAgain (CopiedLink request)))
  let (otherPost, _) = step copied (ChangedURI (Route.routeURI (Post Section.Lab "reconstruct")))
  checkEq "clipboard completion belongs to its mounted post" otherPost
    (fst (step otherPost (CopiedLink request)))
  checkEq "copy completion on home is ignored" home (fst (step home (CopiedLink request)))

  -- Measurements replace the rail state; rail actions schedule one scroll.
  let measured = ReadingProgress 42 [HeadingPosition "a" 2 10]
      (measuredModel, measuredEffects) = step post (MeasuredReadingProgress 0 measured)
      (setModel, setEffects) = step post (SelectedReadingProgress 50)
      (scrolledHome, scrolledEffects) = step home ScrolledContent
  checkEq "MeasuredReadingProgress stores the rail" measured (_reading measuredModel)
  checkEq "MeasuredReadingProgress schedules nothing" 0 measuredEffects
  checkEq "SelectedReadingProgress schedules one scroll" 1 setEffects
  checkEq "SelectedReadingProgress leaves the model alone" post setModel
  checkEq "measurement from an old post is ignored" otherPost
    (fst (step otherPost (MeasuredReadingProgress 0 measured)))
  checkEq "rail selection on home is ignored" (home, 0)
    (step home (SelectedReadingProgress 50))
  checkEq "scrolling away from a post schedules nothing" 0 scrolledEffects
  checkEq "scrolling away from a post changes nothing" home scrolledHome

  -- GitHub responses merge; ready needs both, failure is sticky.
  let activity = GitHubActivity
        { activityContributions = 321
        , activityFollowers = 12
        , activityLevels = [0, 2, 4]
        }
  checkEq "GitHub starts loading" GitHubLoading (GitHub.statusFrom Nothing Nothing False)
  checkEq "a lone profile stays loading" GitHubLoading
          (GitHub.statusFrom (Just (Profile 12)) Nothing False)
  checkEq "a failure is shown" GitHubFailed (GitHub.statusFrom Nothing Nothing True)
  checkEq "both responses are ready" (GitHubReady activity)
          (GitHub.statusFrom (Just (Profile 12)) (Just (Contributions 321 [0, 2, 4])) False)
-----------------------------------------------------------------------------
-- | The prerender catalog. These values are what the generator writes into
-- every page head; the titles mirror the source site exactly.
metaSpec :: Check -> CheckEq -> IO ()
metaSpec check checkEq = do
  checkEq "home title" "Faah" (metaTitle (Meta.metaForRoute Home))
  checkEq "ssh is no longer a page" (NotFound "/ssh") (Route.urlToRoute "/ssh/")
  checkEq "section title" "thought - Faah"
          (metaTitle (Meta.metaForRoute (Section Config.thoughtSection)))
  checkEq "not-found title" "Not found - Faah"
          (metaTitle (Meta.metaForRoute (NotFound "/nope")))
  checkEq "default card type" "website" (metaType (Meta.metaForRoute Home))
  checkEq "unknown post falls back to the site card" "website"
          (metaType (Meta.metaForRoute (Post Config.thoughtSection "a-post")))
  checkEq "canonical home" "https://faah.me/" (Meta.canonicalForRoute Home)
  checkEq "canonical section" "https://faah.me/thought/"
          (Meta.canonicalForRoute (Section Config.thoughtSection))
  check "social image is absolute"
        ("https://" `isPrefixOf` MS.unpack (metaImage (Meta.metaForRoute Home)))
  check "every prerender route path ends in a slash"
        (all (MS.isSuffixOf "/") (map Route.routePath Meta.prerenderRoutes))
  check "anti-flash script reads the configured storage key"
        (MS.isInfixOf ("localStorage.getItem('" <> Config.themeStorageKey <> "')")
          antiFlashScript)
  check "anti-flash script toggles the configured class"
        (MS.isInfixOf ("classList.toggle('" <> Config.darkClassName <> "'")
          antiFlashScript)
  check "anti-flash script tests the configured queries"
        (MS.isInfixOf Config.prefersDarkQuery antiFlashScript)
  check "anti-flash script compares the stored theme names"
        (all (`MS.isInfixOf` antiFlashScript)
          [ "'" <> Theme.storageName Dark <> "'"
          , "'" <> Theme.storageName Light <> "'"
          ])
-----------------------------------------------------------------------------
-- | The generated content catalog and the queries over it. Drafts never
-- surface, published posts are newest first, and post metadata uses the
-- source's fallback chain.
contentSpec :: Check -> CheckEq -> IO ()
contentSpec check checkEq = do
  let published = Content.publishedPosts
  checkEq "published post count" 4 (length published)
  checkEq "newest first slugs"
          [ "reconstruct"
          , "reverse-engineering-grok-build-cli"
          , "chaotic-pendulum"
          , "should-we-rely-on-llm"
          ]
          (map Content.postSlug published)
  check "drafts are excluded"
        (not (any ((== "everyone-is-narcissistic-today") . Content.postSlug) published))
  checkEq "lab has one post" [ "reconstruct" ]
          (map Content.postSlug (Content.postsInSection Config.labSection))
  checkEq "thought has three posts" 3
          (length (Content.postsInSection Config.thoughtSection))
  check "published post is found"
        (maybe False ((== "Chaotic pendulum") . Content.postTitle)
          (Content.findPost Config.thoughtSection "chaotic-pendulum"))
  checkEq "draft is not found" Nothing
          (Content.findPost Config.thoughtSection "everyone-is-narcissistic-today")

  -- Neighbours walk the section chronologically, and the parsed body and TOC
  -- survive generation. Both need the one post, so they share a case.
  case Content.findPost Config.thoughtSection "chaotic-pendulum" of
    Nothing -> check "chaotic-pendulum exists" False
    Just chaotic -> do
      let (older, newer) = Content.neighboringPosts chaotic
      checkEq "older neighbour" (Just "should-we-rely-on-llm")
              (Content.postSlug <$> older)
      checkEq "newer neighbour" (Just "reverse-engineering-grok-build-cli")
              (Content.postSlug <$> newer)
      checkEq "date label is precomputed" "Jun 22, 2026" (Content.postDateLabel chaotic)
      checkEq "first heading anchor" "the-line-the-motion-and-the-point-that-never-arrives"
              (maybe "" Content.tocId (listToMaybe (Content.postToc chaotic)))
      check "the body has footnotes" (any isFootnotes (Content.postBody chaotic))
      check "the grok post body has a table"
            (maybe False (any isTable . Content.postBody)
              (Content.findPost Config.thoughtSection "reverse-engineering-grok-build-cli"))

  -- Post metadata: the Open Graph title wins, the type is article, and the
  -- social image becomes absolute.
  let postMeta = Meta.metaForRoute (Post Config.thoughtSection "chaotic-pendulum")
  checkEq "post meta title" "Chaotic Pendulum: Compassion, Judgment, and the Room That Won't Sit Still"
          (metaTitle postMeta)
  checkEq "post meta type" "article" (metaType postMeta)
  checkEq "post meta image is absolute"
          "https://faah.me/assets/banners/pendulum.png" (metaImage postMeta)
  checkEq "post canonical" "https://faah.me/thought/chaotic-pendulum/"
          (Meta.canonicalForRoute (Post Config.thoughtSection "chaotic-pendulum"))
  check "published posts are prerendered"
        (all (`elem` Meta.prerenderRoutes)
          [ Post (Content.postSection post) (Content.postSlug post)
          | post <- published
          ])
  where
    isFootnotes (Footnotes _) = True
    isFootnotes _             = False
    isTable (Table _ _ _)     = True
    isTable _                 = False
-----------------------------------------------------------------------------
-- | The sea simulation: layout clamps, drag mapping, and the frame math the
-- shader uniforms depend on. No DOM, no GL.
seaSpec :: Check -> CheckEq -> IO ()
seaSpec check checkEq = do

  let layout = Sea.renderLayoutFor 800 600 2.0
  checkEq "canvas width uses the capped ratio" 1200 (Sea.canvasWidth layout)
  checkEq "canvas height uses the capped ratio" 900 (Sea.canvasHeight layout)
  checkEq "scene width shrinks with area" 541 (Sea.sceneWidth layout)
  checkEq "scene height shrinks with area" 406 (Sea.sceneHeight layout)

  let small = Sea.renderLayoutFor 100 100 0.5
  checkEq "pixel ratio floors at one" 1.0 (Sea.pixelRatio small)
  checkEq "scene ratio caps at 0.85" 85 (Sea.sceneWidth small)

  let timing = Sea.frameTiming 2500 1000 500
  checkEq "timing seconds" 2.0 (Sea.timingSeconds timing)
  checkEq "frame duration clamps at 40ms" 40.0 (Sea.timingDuration timing)
  checkEq "intro completes at two seconds" 1.0 (Sea.timingIntro timing)
  checkEq "intro starts at zero" 0.0
          (Sea.timingIntro (Sea.frameTiming 500 500 500))

  let drag = Sea.seaDragTarget 0 0 10 10 110 110 100 100
  checkEq "drag maps x by width" 10.0 (fst drag)
  checkEq "drag maps y by height" (-8.0) (snd drag)
  let clamped = Sea.retargetSeaMotion (10, 20) Sea.initialSeaMotion
  checkEq "drag target clamps x" 7.0 (Sea.motionTargetX clamped)
  checkEq "drag target clamps y" 11.0 (Sea.motionTargetY clamped)

  let state0 = Sea.initialSeaState 0 0
      down = Sea.seaPointer (Sea.SeaPointerEvent Sea.PointerDown 10 10 100 100) state0
      moved = Sea.seaPointer (Sea.SeaPointerEvent Sea.PointerMove 60 (-40) 100 100) down
      up = Sea.seaPointer (Sea.SeaPointerEvent Sea.PointerUp 60 (-40) 100 100) moved
      stray = Sea.seaPointer (Sea.SeaPointerEvent Sea.PointerMove 90 90 100 100) state0
  check "drag starts on pointerdown" (Sea.stateDragging down)
  checkEq "drag retargets x" 5.0 (Sea.motionTargetX (Sea.motion moved))
  -- Dragging up raises the cube; the lower clamp keeps it on the water.
  checkEq "drag retargets y" 4.0 (Sea.motionTargetY (Sea.motion moved))
  check "drag ends on pointerup" (not (Sea.stateDragging up))
  checkEq "move without drag is ignored" 0.0
          (Sea.motionTargetX (Sea.motion stray))

  let input = Sea.SeaInput
        { Sea.inputTimestamp = 1000
        , Sea.inputStartedAt = 0
        , Sea.inputLabHoverTarget = 0
        , Sea.inputCanvasWidth = 400
        , Sea.inputCanvasHeight = 300
        , Sea.inputDark = False
        , Sea.inputReducedMotion = False
        }
      (_, uniforms) = Sea.seaFrame input state0
  checkEq "frame time is seconds since mount" 1.0 (Sea.time uniforms)
  checkEq "uniform resolution y keeps the 1.92 scale" (300 * 1.92)
          (Sea.resolutionY uniforms)
  checkEq "intro ramps at one second" 0.5 (Sea.intro uniforms)
  checkEq "light theme reports zero" 0.0 (Sea.uiDark uniforms)

  let reduced = input
        { Sea.inputReducedMotion = True
        , Sea.inputDark = True
        , Sea.inputLabHoverTarget = 1
        }
      (_, reducedUniforms) = Sea.seaFrame reduced state0
  checkEq "reduced motion freezes time" 0.0 (Sea.time reducedUniforms)
  checkEq "reduced motion completes the intro" 1.0 (Sea.intro reducedUniforms)
  checkEq "reduced motion reports the theme" 1.0 (Sea.uiDark reducedUniforms)
  checkEq "reduced motion reports hover" 1.0 (Sea.labHover reducedUniforms)
-----------------------------------------------------------------------------
-- | The reading rail's math: percentages, the marker line, rounding, and the
-- scroll targets.
scrollSpec :: Check -> CheckEq -> IO ()
scrollSpec _ checkEq = do

  let geometry = Geometry
        { geometryScrollTop = 500
        , geometryScrollHeight = 2500
        , geometryClientHeight = 500
        , geometryRootTop = 0
        , geometryHeadings =
            [ HeadingGeometry "a" 2 400
            , HeadingGeometry "b" 3 900
            ]
        }
      progress = Scroll.readingProgress geometry
  checkEq "scroll percentage" 25 (Scroll.readingPercent progress)
  checkEq "heading percentage uses the 35% marker line" 36
          (maybe 0 Scroll.posProgress (listToMaybe (Scroll.readingHeadings progress)))
  checkEq "empty range reports zero" 0
          (Scroll.readingPercent (Scroll.readingProgress (geometry { geometryScrollHeight = 500 })))
  checkEq "percent clamps low" 0 (Scroll.clampPercent (-10))
  checkEq "percent clamps high" 100 (Scroll.clampPercent 120)
  checkEq "halves round up like JS" 3 (Scroll.clampPercent 2.5)
  checkEq "progress clamps to 0..100" 100 (Scroll.clampProgress 500)
  checkEq "progress target maps percent to range" 1000.0
          (Scroll.progressScrollTarget 2000 50)
  checkEq "progress target clamps" 2000.0
          (Scroll.progressScrollTarget 2000 500)
  checkEq "heading target applies the 128px offset" 1172.0
          (Scroll.headingScrollTarget 500 100 900)
  checkEq "ArrowUp maps to an adjustment"
          (Just (Scroll.AdjustBy (-5)))
          (Scroll.progressCommand "ArrowUp")
  checkEq "Tab is not a slider command"
          Nothing
          (Scroll.progressCommand "Tab")
-----------------------------------------------------------------------------
-- | The GitHub card's JSON shapes and the last-56 derivation.
gitHubSpec :: Check -> CheckEq -> IO ()
gitHubSpec _ checkEq = do

  checkEq "profile decodes"
          (Just (Profile 12))
          (decode "{\"followers\":12}")
  checkEq "contributions decode"
          (Just (Contributions 321 [0, 2, 4]))
          (decode "{\"total\":{\"lastYear\":321},\"contributions\":[{\"level\":0},{\"level\":2},{\"level\":4}]}")
  checkEq "malformed JSON is rejected"
          (Nothing :: Maybe Profile)
          (decode "{\"followers\":\"twelve\"}")
  let activity = GitHub.activityFrom (Profile 12) (Contributions 321 [1 .. 60])
  checkEq "activity keeps the last 56 squares" 56 (length (GitHub.activityLevels activity))
  checkEq "activity keeps the yearly total" 321 (GitHub.activityContributions activity)
  checkEq "activity keeps the follower count" 12 (GitHub.activityFollowers activity)
-----------------------------------------------------------------------------
-- | The scribble's variant selection and animation plan.
scribbleSpec :: Check -> CheckEq -> IO ()
scribbleSpec check checkEq = do

  checkEq "every variant has a path" 4 Scribble.scribbleVariantCount
  check "paths are distinct"
        (length (filter (/= "") [ Scribble.scribblePathAt index | index <- [0 .. 3] ]) == 4)
  checkEq "out-of-range path is empty" "" (Scribble.scribblePathAt 9)
  checkEq "a repeated candidate advances" 3 (Scribble.selectScribble 2 2)
  checkEq "a fresh candidate is kept" 0 (Scribble.selectScribble 3 0)
  checkEq "selection wraps" 0 (Scribble.selectScribble 3 7)
  let plan = Scribble.scribbleAnimation 100.0
      frames = Scribble.animationFrames plan
  checkEq "four keyframes" 4 (length frames)
  checkEq "the stroke starts fully offset" 100.0
          (maybe 0 Scribble.frameDashOffset (listToMaybe frames))
  checkEq "the stroke ends reversed" (-100.0)
          (maybe 0 Scribble.frameDashOffset (listToMaybe (reverse frames)))
  checkEq "offsets cover the cycle" [0.0, 0.24, 0.68, 1.0]
          (map Scribble.frameOffset frames)
  checkEq "the cycle lasts 2.8 seconds" 2800 (Scribble.animationDuration plan)
-----------------------------------------------------------------------------
-- | The hollow mark: mesh shape, drag mapping, reduced-motion frame, and the
-- raster layout clamp.
hollowSpec :: Check -> CheckEq -> IO ()
hollowSpec check checkEq = do

  -- 28 * 64 cells * 2 triangles * 3 vertices per surface, times four
  -- surfaces, plus two rims and the cube.
  checkEq "vertex count" 43812 HollowGeometry.hollowVertexCount
  checkEq "float count" 306684 (length HollowGeometry.hollowVertices)
  checkEq "first vertex is the outer shell pole" [-1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0]
          (take 7 HollowGeometry.hollowVertices)
  checkEq "last vertex is the cube's far corner"
          [0.2, 0.2, -0.2, 0.0, 0.0, -1.0, 6.0]
          (drop (length HollowGeometry.hollowVertices - 7) HollowGeometry.hollowVertices)

  let state = Hollow.initialHollowState 0
      down = Hollow.hollowPointer (Hollow.HollowPointerEvent Hollow.HollowDown 50 10 100 100) state
      moved = Hollow.hollowPointer (Hollow.HollowPointerEvent Hollow.HollowMove 75 10 150 100) down
      up = Hollow.hollowPointer (Hollow.HollowPointerEvent Hollow.HollowUp 75 10 200 100) moved
  check "drag starts on pointerdown" (Hollow.hsDragging down)
  checkEq "drag maps a quarter width to a quarter turn" (pi / 2)
          (Hollow.hmTargetAngle (Hollow.hsMotion moved))
  check "drag ends on pointerup" (not (Hollow.hsDragging up))

  let input = Hollow.HollowInput
        { Hollow.hiTimestamp = 0
        , Hollow.hiStartedAt = 0
        , Hollow.hiReduceMotion = True
        , Hollow.hiLabHoverTarget = 0
        , Hollow.hiCanvasWidth = 200
        , Hollow.hiCanvasHeight = 100
        }
      (_, uniforms) = Hollow.hollowFrame input state
  checkEq "reduced motion freezes the clock" 0.0 (Hollow.huTime uniforms)
  checkEq "reduced motion parks the cube" 0.48 (Hollow.huCubeAngle uniforms)
  checkEq "aspect is width over height" 2.0 (Hollow.huAspect uniforms)

  let layout = Canvas.rasterLayout 100 50 2.0 1.0 6.0
  checkEq "raster width scales by the ratio" 200 (Canvas.rasterCanvasWidth layout)
  checkEq "raster height scales by the ratio" 100 (Canvas.rasterCanvasHeight layout)
  checkEq "raster ratio clamps high" 6.0
          (Canvas.rasterPixelRatio (Canvas.rasterLayout 10 10 9.0 1.0 6.0))
  checkEq "raster ratio clamps low" 1.0
          (Canvas.rasterPixelRatio (Canvas.rasterLayout 10 10 0.5 1.0 6.0))
-----------------------------------------------------------------------------
-- | The dithered image: ink parsing, the source/canvas letterbox, and the
-- ~20fps draw gate.
ditherSpec :: Check -> CheckEq -> IO ()
ditherSpec check checkEq = do

  checkEq "parses a six-digit hex ink" (Just Dither.fallbackColor)
          (Dither.parseColor "#ff4b26")
  checkEq "parses a three-digit hex ink" (Dither.parseColor "#ff4422")
          (Dither.parseColor "#f42")
  checkEq "accepts hex without the hash" (Dither.parseColor "#abcdef")
          (Dither.parseColor "abcdef")
  checkEq "rejects a functional color" (Nothing :: Maybe Dither.Rgb)
          (Dither.parseColor "rgb(255, 75, 38)")
  checkEq "rejects non-hex digits" (Nothing :: Maybe Dither.Rgb)
          (Dither.parseColor "#gggggg")
  checkEq "missing ink falls back" Dither.fallbackColor
          (Dither.ditherColor "")
  checkEq "an unknown hex falls back" Dither.fallbackColor
          (Dither.ditherColor "#ff4b2")

  checkEq "channels are normalized" 1.0 (Dither.rgbRed Dither.fallbackColor)
  checkEq "green is 75/255" (75 / 255) (Dither.rgbGreen Dither.fallbackColor)
  checkEq "blue is 38/255" (38 / 255) (Dither.rgbBlue Dither.fallbackColor)

  -- A square source in a square box fills it: no crop, no clamp.
  let square = Dither.ditherLayout Dither.DitherLayoutInput
        { Dither.dliWidth = 100
        , Dither.dliHeight = 100
        , Dither.dliDevicePixelRatio = 3.0
        , Dither.dliSourceWidth = 100
        , Dither.dliSourceHeight = 100
        }
  checkEq "the raster ratio clamps to 2x" 200 (Dither.dlCanvasWidth square)
  checkEq "the css size is unchanged" 100 (Dither.dlCssWidth square)
  checkEq "a matching source has full coordinates"
          [0, 0, 1, 0, 0, 1, 1, 1]
          (Dither.dlTextureCoordinates square)

  -- A wide source in a square box crops left and right by a quarter each.
  let wide = Dither.ditherLayout Dither.DitherLayoutInput
        { Dither.dliWidth = 100
        , Dither.dliHeight = 100
        , Dither.dliDevicePixelRatio = 1.0
        , Dither.dliSourceWidth = 200
        , Dither.dliSourceHeight = 100
        }
      tall = Dither.ditherLayout Dither.DitherLayoutInput
        { Dither.dliWidth = 100
        , Dither.dliHeight = 100
        , Dither.dliDevicePixelRatio = 1.0
        , Dither.dliSourceWidth = 100
        , Dither.dliSourceHeight = 200
        }
  checkEq "a wide source crops the sides"
          [0.25, 0, 0.75, 0, 0.25, 1, 0.75, 1]
          (Dither.dlTextureCoordinates wide)
  checkEq "a tall source crops the top and bottom"
          [0, 0.25, 1, 0.25, 0, 0.75, 1, 0.75]
          (Dither.dlTextureCoordinates tall)

  check "a frame inside 50ms is gated" (not (Dither.shouldDrawFrame False 49 0))
  check "a frame at 50ms is drawn" (Dither.shouldDrawFrame False 50 0)
  check "reduced motion draws every frame" (Dither.shouldDrawFrame True 0 0)
  checkEq "eight quad vertices" 8 (length Dither.quadVertices)
  checkEq "sixteen bayer entries" 16 (length Dither.bayerMatrix)
  checkEq "the bayer matrix tops out at 240" 240 (maximum Dither.bayerMatrix)
-----------------------------------------------------------------------------
-- | The frame scheduler: coalescing, on-demand one-shot frames, visibility
-- cancellation, and continuous self-rescheduling. The driver and the clock are
-- fakes, so this runs natively.
frameLoopSpec :: Check -> CheckEq -> IO ()
frameLoopSpec check checkEq = do
  drawCount <- newIORef (0 :: Int)
  requests <- newIORef (0 :: Int)
  cancels <- newIORef (0 :: Int)
  tickRef <- newIORef (Nothing :: Maybe (Double -> IO ()))
  let driver = Frame.FrameDriver
        { Frame.requestFrame = modifyIORef' requests (+ 1) >> pure 1
        , Frame.cancelFrame = \_ -> modifyIORef' cancels (+ 1)
        }
      install tick = writeIORef tickRef (Just tick) >> pure driver
      draw _ = modifyIORef' drawCount (+ 1)
      tick timestamp = maybe (pure ()) ($ timestamp) =<< readIORef tickRef

  onDemand <- Frame.newFrameLoop Frame.OnDemand install draw
  Frame.setVisible onDemand True
  Frame.invalidate onDemand
  Frame.invalidate onDemand
  checkEq "repeated invalidation arms one frame" 1 =<< readIORef requests
  tick 16.0
  checkEq "the on-demand frame draws once" 1 =<< readIORef drawCount
  checkEq "an on-demand frame does not reschedule itself" 1 =<< readIORef requests

  Frame.invalidate onDemand
  Frame.setVisible onDemand False
  checkEq "hiding cancels the pending frame" 1 =<< readIORef cancels
  tick 32.0
  checkEq "a frame delivered while hidden does not draw" 1 =<< readIORef drawCount
  Frame.invalidate onDemand
  checkEq "a hidden loop does not schedule" 2 =<< readIORef requests
  Frame.setVisible onDemand True
  checkEq "becoming visible schedules again" 3 =<< readIORef requests
  Frame.dispose onDemand
  checkEq "dispose cancels the armed frame" 2 =<< readIORef cancels

  continuousDraws <- newIORef (0 :: Int)
  let continuousDraw _ = modifyIORef' continuousDraws (+ 1)
  continuous <- Frame.newFrameLoop Frame.Continuous install continuousDraw
  Frame.setVisible continuous True
  Frame.invalidate continuous
  tick 1.0
  tick 2.0
  checkEq "a continuous loop keeps drawing" 2 =<< readIORef continuousDraws
  Frame.dispose continuous
-----------------------------------------------------------------------------
-- | The palette is declared once in the Tailwind theme; the views must use
-- the generated utilities rather than raw hex values.
paletteSpec :: Check -> IO ()
paletteSpec check = do
  css <- readFile "styles/input.css"
  forM_ tokens $ \token ->
    check ("styles/input.css defines " <> token) (token `isInfixOf` css)
  forM_ views $ \file -> do
    source <- readFile file
    check (file <> " uses palette utilities, not raw hexes")
      (not (any (`isInfixOf` source) rawPalette))
  where
    tokens =
      [ "--color-paper:"
      , "--color-ink:"
      , "--color-coral:"
      , "--color-coral-bright:"
      , "--color-coral-deep:"
      , "--color-hairline:"
      , "--dither-ink: var(--color-coral)"
      ]
    views =
      [ "src/Site/View.hs"
      , "src/Site/View/Home.hs"
      , "src/Site/View/Post.hs"
      , "src/Site/View/Section.hs"
      ]
    rawPalette =
      [ "#FF4B26", "#FF6B4A", "#C24120"
      , "[#171717]", "[#E5E5E5]", "[#F5F5F5]"
      ]
-----------------------------------------------------------------------------
-- | Run one action against one model, purely.
--
-- 'runEffect' is 'execRWS'. The 'Miso.Effect.ComponentInfo' it needs is
-- mostly identity and a DOM reference; nothing in 'Site.Update' reads it, and
-- the reference is never dereferenced because scheduled effects are returned
-- rather than run.
runStep :: Widgets.Runtime -> Model -> Action -> (Model, Int)
runStep widgets model action =
  let (next, schedules) = runEffect (updateModel widgets action) info model
  in (next, length schedules)
  where
     info = mkComponentInfo 0 0 jsNull () ()

-- Derived observations: the model no longer stores duplicate motion/pending
-- fields or post chrome outside the mounted page.
_motion :: Model -> RouteMotion
_motion = navigationMotion . _navigation

_pendingNavigation :: Model -> Maybe Route
_pendingNavigation = pendingRoute . _navigation

_copyStatus :: Model -> CopyStatus
_copyStatus model = case _page model of
  PostPage _ _ state -> postCopyStatus state
  _ -> NotCopied

_reading :: Model -> ReadingProgress
_reading model = case _page model of
  PostPage _ _ state -> postReading state
  _ -> Scroll.emptyReadingProgress

contains :: String -> String -> Bool
contains needle = not . null . dropUntil needle

dropUntil :: String -> String -> String
dropUntil needle source
  | needle `isPrefixOf` source = source
dropUntil _ [] = []
dropUntil needle (_ : rest) = dropUntil needle rest
