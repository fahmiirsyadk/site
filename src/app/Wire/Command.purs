module App.Wire.Command where

import App.Command as Command
import Domain.Theme as Theme

type RawFields =
  { _tag :: String
  , url :: String
  , href :: String
  , theme :: String
  , username :: String
  , title :: String
  , description :: String
  , image :: String
  , contentType :: String
  }

newtype RawCommand = RawCommand RawFields

commandTags :: Array String
commandTags =
  [ "NavigateInternal"
  , "LoadExternal"
  , "StartRouteEntry"
  , "LoadGitHub"
  , "CopyPostLink"
  , "ResetCopyStatus"
  , "ReadTheme"
  , "PersistTheme"
  , "ResetScroll"
  , "SyncDocumentMetadata"
  ]

encode :: Command.Command -> RawCommand
encode command = case command of
  Command.NavigateInternal url -> modifyRaw (emptyRaw "NavigateInternal") (_ { url = url })
  Command.LoadExternal href -> modifyRaw (emptyRaw "LoadExternal") (_ { href = href })
  Command.StartRouteEntry -> emptyRaw "StartRouteEntry"
  Command.LoadGitHub username -> modifyRaw (emptyRaw "LoadGitHub") (_ { username = username })
  Command.CopyPostLink url -> modifyRaw (emptyRaw "CopyPostLink") (_ { url = url })
  Command.ResetCopyStatus -> emptyRaw "ResetCopyStatus"
  Command.ReadTheme -> emptyRaw "ReadTheme"
  Command.PersistTheme theme -> modifyRaw (emptyRaw "PersistTheme") (_ { theme = Theme.toString theme })
  Command.ResetScroll -> emptyRaw "ResetScroll"
  Command.SyncDocumentMetadata metadata -> modifyRaw (emptyRaw "SyncDocumentMetadata")
    (_
      { title = metadata.title
      , description = metadata.description
      , image = metadata.image
      , contentType = metadata.contentType
      })

emptyRaw :: String -> RawCommand
emptyRaw tag = RawCommand
  { _tag: tag
  , url: ""
  , href: ""
  , theme: ""
  , username: ""
  , title: ""
  , description: ""
  , image: ""
  , contentType: ""
  }

modifyRaw :: RawCommand -> (RawFields -> RawFields) -> RawCommand
modifyRaw (RawCommand raw) updateFields = RawCommand (updateFields raw)
