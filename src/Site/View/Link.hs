-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The internal link, shared by every view module so the page views do not
-- have to import the shell (and the shell can import them).
--
-- @href@ is the real path, so the link is a link: it shows in the status bar,
-- is crawlable, and works before hydration. The click is then intercepted so
-- the shell can animate.
module Site.View.Link
  ( Node
  , Attr
  , internalLink
  ) where
-----------------------------------------------------------------------------
import           Miso (View)
import           Miso.Event (Decoder, at, on)
import           Miso.Html.Element as H
import           Miso.Html.Property as P
import           Miso.JSON (withObject, (.:), (.:?))
import           Miso.Types (Attribute)
-----------------------------------------------------------------------------
import           Site.Action (Action (..))
import qualified Site.Model as Model
import           Site.Route (Route)
import qualified Site.Route as Route
-----------------------------------------------------------------------------
type Node context = View context Model.Model Action
type Attr = Attribute Model.Model Action
-----------------------------------------------------------------------------
data LinkClick = LinkClick
  { clickButton :: Maybe Int
  , clickCtrl   :: Bool
  , clickMeta   :: Bool
  , clickShift  :: Bool
  , clickAlt    :: Bool
  }

linkClickDecoder :: Decoder LinkClick
linkClickDecoder = at [] $ withObject "internal link click" $ \object ->
  LinkClick
    <$> object .:? "button"
    <*> object .: "ctrlKey"
    <*> object .: "metaKey"
    <*> object .: "shiftKey"
    <*> object .: "altKey"

interceptableClick :: LinkClick -> Bool
interceptableClick click =
  maybe True (== 0) (clickButton click)
    && not (clickCtrl click || clickMeta click || clickShift click || clickAlt click)
-----------------------------------------------------------------------------
internalLink :: Route -> [Attr] -> [Node context] -> Node context
internalLink target attributes =
  H.a_
    ( P.href_ (Route.routePath target)
    : P.data_ "internal-link" "true"
    : on "click" linkClickDecoder (\click _ _ ->
        if interceptableClick click
          then FollowedLink target
          else IgnoredLinkClick)
    : attributes
    )
