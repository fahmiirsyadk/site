-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The GitHub card's data: the two endpoints, their JSON shapes, and the
-- pure derivation of the card's activity. Ported from the source's
-- @Domain.GitHub@ and @Platform.GitHub@.
--
-- The fetches themselves are 'Miso.Fetch.getJSON' effects issued by
-- 'Site.Update'; this module stays pure so the native tests can decode
-- fixtures without a browser.
module Site.GitHub
  ( Profile (..)
  , Contribution (..)
  , Contributions (..)
  , GitHubActivity (..)
  , GitHubStatus (..)
  , profileUrl
  , contributionsUrl
  , activityFrom
  , statusFrom
  ) where
-----------------------------------------------------------------------------
import           Miso.JSON (FromJSON (..), withObject, (.:))
import           Miso.String (MisoString)
-----------------------------------------------------------------------------
import qualified Site.Config as Config
-----------------------------------------------------------------------------
data Profile = Profile
  { profileFollowers :: Int
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
newtype Contribution = Contribution
  { contributionLevel :: Int
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | The shape the card consumes: the yearly total and the recent levels.
data Contributions = Contributions
  { contributionsLastYear :: Int
  , contributionsLevels   :: [Int]
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
data GitHubActivity = GitHubActivity
  { activityContributions :: Int
  , activityFollowers     :: Int
  , activityLevels        :: [Int]
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
-- | What the card can show. The fetches resolve independently, so loading is
-- the state where either response is still missing.
data GitHubStatus
  = GitHubLoading
  | GitHubFailed
  | GitHubReady GitHubActivity
  deriving (Show, Eq)
-----------------------------------------------------------------------------
profileUrl :: MisoString
profileUrl = "https://api.github.com/users/" <> Config.githubUsername
-----------------------------------------------------------------------------
contributionsUrl :: MisoString
contributionsUrl =
  "https://github-contributions-api.jogruber.de/v4/"
    <> Config.githubUsername
    <> "?y=last"
-----------------------------------------------------------------------------
instance FromJSON Profile where
  parseJSON = withObject "GitHub profile" $ \object ->
    Profile <$> object .: "followers"
-----------------------------------------------------------------------------
instance FromJSON Contribution where
  parseJSON = withObject "GitHub contribution" $ \object ->
    Contribution <$> object .: "level"
-----------------------------------------------------------------------------
instance FromJSON Contributions where
  parseJSON = withObject "GitHub contributions" $ \object -> do
    lastYear <- object .: "total" >>= (.: "lastYear")
    levels <- map contributionLevel <$> object .: "contributions"
    pure Contributions
      { contributionsLastYear = lastYear
      , contributionsLevels = levels
      }
-----------------------------------------------------------------------------
-- | The source took the last 56 squares and mapped them in column-major
-- order, which is what the four-row grid expects.
activityFrom :: Profile -> Contributions -> GitHubActivity
activityFrom profile contributions = GitHubActivity
  { activityContributions = contributionsLastYear contributions
  , activityFollowers = profileFollowers profile
  , activityLevels = takeEnd 56 (contributionsLevels contributions)
  }
  where
    takeEnd count values = drop (max 0 (length values - count)) values
-----------------------------------------------------------------------------
statusFrom :: Maybe Profile -> Maybe Contributions -> Bool -> GitHubStatus
statusFrom (Just profile) (Just contributions) _ =
  GitHubReady (activityFrom profile contributions)
statusFrom _ _ True = GitHubFailed
statusFrom _ _ _ = GitHubLoading
