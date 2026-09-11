-----------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- | The metadata catalog: one record per route, driving @\<title\>@, the
-- description, the social card, and the canonical URL.
--
-- This is the single source of truth for per-route metadata. The prerender
-- generator reads it to write the head of every static page, and the same
-- values can drive future client-side title updates without a second list.
--
-- Posts take their title, description, and social image from the content
-- catalog, with the same fallbacks the source site applied.
module Site.Meta
  ( Meta (..)
  , metaForRoute
  , canonicalForRoute
  , prerenderRoutes
  ) where
-----------------------------------------------------------------------------
import           Miso.String (MisoString)
import qualified Miso.String as MS
-----------------------------------------------------------------------------
import qualified Site.Config as Config
import qualified Site.Content as Content
import           Site.Route (Route (..))
import qualified Site.Route as Route
import           Site.Section (sectionName)
-----------------------------------------------------------------------------
data Meta = Meta
  { metaTitle       :: MisoString
  , metaDescription :: MisoString
  , metaImage       :: MisoString
  -- ^ Absolute URL, so the card works from any route depth.
  , metaType        :: MisoString
  -- ^ Open Graph type: @website@ or @article@.
  } deriving (Show, Eq)
-----------------------------------------------------------------------------
defaultMeta :: Meta
defaultMeta = Meta
  { metaTitle       = Config.siteName
  , metaDescription = Config.siteDescription
  , metaImage       = Config.siteUrl <> Config.defaultSocialImage
  , metaType        = "website"
  }
-----------------------------------------------------------------------------
-- | Mirrors the source site's titles where the page still exists: @Faah@,
-- @thought - Faah@, @lab - Faah@, @Not found - Faah@. Posts use their own
-- frontmatter, with the source's fallback chain.
metaForRoute :: Route -> Meta
metaForRoute = \case
  Home            -> defaultMeta
  Section section -> defaultMeta { metaTitle = sectionName section <> " - " <> Config.siteName }
  Post section slug ->
    maybe notFoundMeta postMeta (Content.findPost section slug)
  NotFound _      -> notFoundMeta
-----------------------------------------------------------------------------
notFoundMeta :: Meta
notFoundMeta = defaultMeta
  { metaTitle       = "Not found - " <> Config.siteName
  , metaDescription = "There is nothing at this address."
  }
-----------------------------------------------------------------------------
postMeta :: Content.Post -> Meta
postMeta post = Meta
  { metaTitle       = firstOf [Content.postOgTitle post, Content.postTitle post]
  , metaDescription = firstOf
      [ Content.postOgDescription post
      , Content.postExcerpt post
      , Config.siteDescription
      ]
  , metaImage       = absoluteImage (firstOf
      [ Content.postOgImage post
      , Content.postBanner post
      , Config.defaultSocialImage
      ])
  , metaType        = "article"
  }
  where
    firstOf = foldr (\candidate fallback -> if candidate == "" then fallback else candidate) ""
    absoluteImage image
      | MS.isPrefixOf "http" image = image
      | otherwise = Config.siteUrl <> image
-----------------------------------------------------------------------------
-- | Every route path already carries its trailing slash, which is the
-- canonical form the deployed site serves.
canonicalForRoute :: Route -> MisoString
canonicalForRoute route = Config.siteUrl <> Route.routePath route
-----------------------------------------------------------------------------
-- | Routes the prerender generator writes to disk: the fixed pages plus every
-- published post.
prerenderRoutes :: [Route]
prerenderRoutes =
  [ Home
  , Section Config.thoughtSection
  , Section Config.labSection
  ]
  <> [ Post (Content.postSection post) (Content.postSlug post)
     | post <- Content.publishedPosts
     ]
