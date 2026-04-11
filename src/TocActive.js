"use strict";

function isMobileTocViewport() {
  try {
    return typeof matchMedia !== "undefined" && matchMedia("(max-width: 767px)").matches;
  } catch (_) {
    return false;
  }
}

function computeActiveTocId() {
  // TOC links live in the desktop aside and in the mobile drawer (not in aside when md:hidden).
  var links = Array.from(document.querySelectorAll("a[data-toc-id]"));
  var seen = Object.create(null);
  var ids = [];
  for (var j = 0; j < links.length; j++) {
    var id = links[j].getAttribute("data-toc-id");
    if (id && !seen[id]) {
      seen[id] = true;
      ids.push(id);
    }
  }

  if (ids.length === 0) return null;

  // Keep `ids` in document order of first matching `a[data-toc-id]` (mobile drawer, then aside).
  // That matches the authored TOC order; sorting headings with compareDocumentPosition was unreliable
  // across browsers and could break the active-section walk.
  var headings = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
  if (headings.length === 0) return null;

  // Account for fixed mobile top bar (~3–5rem + safe area).
  var nav = document.querySelector("nav.mobile-site-nav");
  var navH = 0;
  if (nav) {
    var r = nav.getBoundingClientRect();
    navH = r.bottom > 0 ? r.bottom : 0;
  }
  var threshold = Math.max(100, Math.round(navH + 24));

  var candidate = headings[0].id;
  for (var i = 0; i < headings.length; i++) {
    var top = headings[i].getBoundingClientRect().top;
    if (top <= threshold) candidate = headings[i].id;
    else break;
  }

  return candidate || null;
}

export function setupScrollSpyImpl(containerId, callback) {
  var el = document.getElementById(containerId);
  if (!el) return;

  var rafId = 0;
  var run = function () {
    // Desktop only: TOC follows scroll. Mobile uses URL hash (initial load + hashchange) only.
    if (isMobileTocViewport()) return;
    callback(computeActiveTocId())();
  };

  el._siteTocSpyTick = run;

  el.addEventListener("scroll", function () {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(function () {
      rafId = 0;
      run();
    });
  }, { passive: true });

  requestAnimationFrame(run);
  window.addEventListener("resize", function () {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(function () {
      rafId = 0;
      run();
    });
  }, { passive: true });
}

export function tickScrollSpyImpl(containerId) {
  var el = document.getElementById(containerId);
  if (!el || typeof el._siteTocSpyTick !== "function") return;
  el._siteTocSpyTick();
}
