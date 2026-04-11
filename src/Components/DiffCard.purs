module Components.DiffCard (diffCard) where

import BodyBlockHtml as BBH
import Components.ToolCard (toolDisplayIslandCard)
import Data.Maybe (Maybe)
import Luna.Html (Html)
import Types (ToolCardState)

diffCard
  :: forall i
   . ToolCardState
  -> (String -> i)
  -> { id :: String, file :: String, addStat :: Maybe String, delStat :: Maybe String, content :: String }
  -> Html i
diffCard state onToggle r =
  toolDisplayIslandCard state onToggle
    { id: r.id
    , file: r.file
    , addStat: r.addStat
    , delStat: r.delStat
    , bodyInnerHtml: BBH.renderDiffCardBodyHtml r.content
    , expandSrOnly: "Expand diff"
    }
