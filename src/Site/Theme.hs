{-# LANGUAGE OverloadedStrings #-}
module Site.Theme
  ( x_
  , mk
  , rawHtml
  , sunSvg
  , moonSvg
  , menuButtonIconSvg
  , cubeLogoFallbackSvg
  , themeBootScript
  , relativeTimeScript
  ) where

import Lucid
import Lucid.Base (makeAttribute)
import Data.Text (Text)

x_ :: Text -> Text -> Attribute
x_ key val = makeAttribute ("x-" <> key) val

mk :: Text -> Text -> Attribute
mk = makeAttribute

rawHtml :: Text -> Html ()
rawHtml = toHtmlRaw

sunSvg :: Text
sunSvg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"pointer-events-none\" aria-hidden=\"true\"><path d=\"M12 12m-4 0a4 4 0 1 0 8 0a4 4 0 1 0 -8 0\"/><path d=\"M3 12h1m8 -9v1m8 8h1m-9 8v1M5.6 5.6l.7 .7m12.1 -.7l-.7 .7m0 11.4l.7 .7m-12.1 -.7l-.7 .7\"/></svg>"

moonSvg :: Text
moonSvg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.75\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"pointer-events-none\" aria-hidden=\"true\"><path d=\"M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454z\"/></svg>"

menuButtonIconSvg :: Text
menuButtonIconSvg = "<span class=\"flex h-5 w-5 flex-col items-center justify-center gap-1\" aria-hidden=\"true\"><span class=\"block h-0.5 w-4 rounded-full bg-current\"></span><span class=\"block h-0.5 w-4 rounded-full bg-current\"></span><span class=\"block h-0.5 w-4 rounded-full bg-current\"></span></span>"

cubeLogoFallbackSvg :: Text
cubeLogoFallbackSvg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 36 36\" width=\"36\" height=\"36\" fill=\"none\" stroke=\"#FF4B26\" stroke-width=\"2\" stroke-linejoin=\"round\" stroke-linecap=\"round\"><path d=\"M18 4 L31 11 L31 25 L18 32 L5 25 L5 11 Z\"/><path d=\"M18 18 L31 11 M18 18 L18 32 M18 18 L5 25\"/></svg>"

themeBootScript :: Text
themeBootScript = "(function(){try{var h=document.documentElement;var s=localStorage.getItem('theme');if(s==='dark'){h.classList.add('dark');h.style.colorScheme='dark'}else{h.classList.remove('dark');h.style.colorScheme='light'}}catch(e){var h=document.documentElement;h.classList.remove('dark');h.style.colorScheme='light'}})();"

relativeTimeScript :: Text
relativeTimeScript = "window.__relTime=function(){function fmt(d){var s=Math.max(1,Math.floor((Date.now()-d.getTime())/1000));if(s<60)return'just now';var m=Math.floor(s/60);if(m<60)return m+(m===1?' min ago':' min ago');var h=Math.floor(m/60);if(h<24)return h+(h===1?' hr ago':' hr ago');var days=Math.floor(h/24);if(days<7)return days+(days===1?' day ago':' days ago');var w=Math.floor(days/7);if(w<5)return w+(w===1?' wk ago':' wk ago');var mo=Math.round(days/30);if(mo<12)return mo+' mo. ago';var yr=Math.round(days/365);return Math.max(1,yr)+' yr. ago'}var nodes=document.querySelectorAll('[data-relative-date]');for(var i=0;i<nodes.length;i++){var n=nodes[i];var raw=n.getAttribute('data-relative-date');if(!raw)continue;var d=new Date(raw);if(!isNaN(d.getTime()))n.textContent=fmt(d)}};window.__relTime();"
