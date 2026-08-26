module Platform.GitHub where

import Prelude

import Data.Array as Array
import Data.Function.Uncurried (Fn2, runFn2)
import Domain.GitHub as Domain
import Platform.Effect as PE
import PursTs.Effect as Fx

type GitHubError =
  { message :: String
  }

type Profile = Domain.Profile

type Contributions = Domain.Contributions

type Activity = Domain.Activity

foreign import data Response :: Type

foreign import data Payload :: Type

foreign import fetchImpl :: Fn2 String Fx.Signal (Fx.Promise Response)

foreign import okStatusImpl :: Response -> Boolean

foreign import bodyJsonImpl :: Response -> Fx.Promise Payload

foreign import decodeProfileImpl :: Payload -> Fx.Effect Fx.Rejected Fx.NoServices Profile

foreign import decodeContributionsImpl :: Payload -> Fx.Effect Fx.Rejected Fx.NoServices Contributions

failed :: GitHubError
failed = { message: "GitHub request failed" }

recover :: Fx.Rejected -> GitHubError
recover _ = failed

attempt :: forall value. (Fx.Signal -> Fx.Promise value) -> Fx.Effect GitHubError Fx.NoServices value
attempt run = Fx.tryPromise { attempt: run, recover }

validate
  :: forall value
   . Fx.Effect Fx.Rejected Fx.NoServices value
  -> Fx.Effect GitHubError Fx.NoServices value
validate response = Fx.mapError response (const failed)

profileUrl :: String -> String
profileUrl username = "https://api.github.com/users/" <> username

contributionsUrl :: String -> String
contributionsUrl username =
  "https://github-contributions-api.jogruber.de/v4/" <> username <> "?y=last"

getJson :: String -> Fx.Effect GitHubError Fx.NoServices Payload
getJson url = do
  response <- attempt (\signal -> runFn2 fetchImpl url signal)
  if okStatusImpl response then attempt (\signal -> bodyJsonImpl response)
    else PE.throwError failed

decodeProfile :: Payload -> Fx.Effect GitHubError Fx.NoServices Profile
decodeProfile = validate <<< decodeProfileImpl

decodeContributions :: Payload -> Fx.Effect GitHubError Fx.NoServices Contributions
decodeContributions = validate <<< decodeContributionsImpl

fetchProfile :: String -> Fx.Effect GitHubError Fx.NoServices Profile
fetchProfile username = getJson (profileUrl username) >>= decodeProfile

fetchContributions :: String -> Fx.Effect GitHubError Fx.NoServices Contributions
fetchContributions username =
  getJson (contributionsUrl username) >>= decodeContributions

load :: String -> Fx.Effect GitHubError Fx.NoServices Activity
load username = do
  responses <- Fx.zipPar (fetchProfile username) (fetchContributions username)
  pure (activityFromResponses responses.first responses.second)

activityFromResponses :: Profile -> Contributions -> Activity
activityFromResponses profile contributions =
  { contributions: contributions.total.lastYear
  , followers: profile.followers
  , levels: Array.takeEnd 56 (map (\contribution -> contribution.level) contributions.contributions)
  }
