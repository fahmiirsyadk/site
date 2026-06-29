/* spa.js -- client-side soft navigation for the Slick/Lucid static site.
   Intercepts same-origin link clicks, fetches the target page, and swaps only
   the #page-view fragment instead of doing a full document load. Uses the
   View Transitions API for the cross-fade when available (and motion is allowed).

   The persistent chrome (nav + footer, including the WebGL cube logo and sea
   canvas) lives OUTSIDE #page-view, so it is never re-mounted across navigations.
   Only the article/section body and a handful of head tags are updated. */
(function () {
  "use strict";

  if (typeof window === "undefined" || typeof document === "undefined") return;

  var rm = window.matchMedia ? window.matchMedia("(prefers-reduced-motion: reduce)") : null;
  function reduceMotion() { return !!(rm && rm.matches); }

  // Don't fight the browser's own scroll restoration; we manage it explicitly.
  if ("scrollRestoration" in history) history.scrollRestoration = "manual";

  function pageView() { return document.getElementById("page-view"); }
  function contentScroll() { return document.getElementById("content-scroll"); }

  // ----------------------------------------------------------------------
  // Link interception
  // ----------------------------------------------------------------------

  // Returns a URL to navigate to, or null if the click should be left alone.
  function interceptTarget(e) {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return null;
    var t = e.target;
    if (!(t instanceof Element)) return null;
    var link = t.closest("a[href]");
    if (!link) return null;
    if (link.target === "_blank" || link.hasAttribute("download") || link.getAttribute("rel") === "external") return null;

    var href = link.getAttribute("href");
    if (!href || href.charAt(0) === "#") return null;

    var url;
    try { url = new URL(link.href, location.href); } catch (_) { return null; }
    if (url.origin !== location.origin) return null;

    // Skip links that point at a real file (e.g. /assets/foo.png) — let the
    // browser handle those normally. Pretty URLs (no extension or .html) pass.
    var last = url.pathname.split("/").pop();
    if (last.indexOf(".") !== -1 && !/\.html?$/i.test(last)) return null;

    return url;
  }

  // ----------------------------------------------------------------------
  // DOM/head reconciliation
  // ----------------------------------------------------------------------

  // Reflect the active route in both the desktop and mobile nav. Active state
  // is applied as an inline color override so it works regardless of which
  // Tailwind utility classes the server rendered.
  function patchNav(path) {
    var bare = path.replace(/\/$/, "");
    var links = document.querySelectorAll("[data-site-nav] a[href]");
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var ap = a.getAttribute("href") || "";
      var active = ap === path || ap === bare || ap + "/" === path;
      a.style.color = active ? "#FF4B26" : "";
      a.style.textDecorationColor = active ? "#FF4B26" : "";
    }
  }

  // Replace the social/SEO meta tags with the incoming page's set.
  function patchMeta(doc) {
    var sel = 'meta[property^="og:"],meta[name^="twitter:"]';
    document.querySelectorAll(sel).forEach(function (m) { m.parentNode.removeChild(m); });
    doc.querySelectorAll(sel).forEach(function (m) { document.head.appendChild(m); });
  }

  function updateDocument(doc, path) {
    var incoming = doc.querySelector("#page-view");
    var current = pageView();
    if (!incoming || !current) { location.href = path; return; }

    current.innerHTML = incoming.innerHTML;

    var title = doc.querySelector("title");
    if (title) document.title = title.textContent || "";

    patchMeta(doc);
    patchNav(path);

    // Close any open mobile-nav drawer left over from the click.
    document.querySelectorAll("details[open]").forEach(function (d) { d.open = false; });

    var sc = contentScroll();
    if (sc) sc.scrollTo(0, 0);
    window.scrollTo(0, 0);

    // Re-run progressive enhancements that target freshly inserted nodes.
    if (current.querySelector("[data-relative-date]") && window.__relTime) window.__relTime();
    if (current.querySelector(".cover-scene") && window.__coverInit) window.__coverInit();
  }

  // ----------------------------------------------------------------------
  // Navigation
  // ----------------------------------------------------------------------

  function render(doc, path) {
    var apply = function () { updateDocument(doc, path); };
    if (document.startViewTransition && !reduceMotion()) {
      document.startViewTransition(apply);
    } else {
      apply();
    }
  }

  // Fetch happens BEFORE the view transition so the cross-fade snapshot isn't
  // held open across the network round-trip.
  function navigate(path) {
    return fetch(path, { headers: { Accept: "text/html" } })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.text();
      })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, "text/html");
        render(doc, path);
      })
      .catch(function () { location.href = path; });
  }

  document.addEventListener("click", function (e) {
    var url = interceptTarget(e);
    if (!url) return;
    var path = url.pathname + url.search + url.hash;
    e.preventDefault();
    if (path === location.pathname + location.search + location.hash) return;
    history.pushState(null, "", path);
    navigate(url.pathname + url.search);
  });

  window.addEventListener("popstate", function () {
    navigate(location.pathname + location.search);
  });
})();
