"use strict";

function computeActiveTocId() {
  var ids = Array.from(document.querySelectorAll("aside a[data-toc-id]"))
    .map(function (link) { return link.getAttribute("data-toc-id"); })
    .filter(Boolean);

  if (ids.length === 0) return null;

  var headings = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
  if (headings.length === 0) return null;

  var candidate = headings[0].id;
  var threshold = 140;
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
  el.addEventListener("scroll", function () {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(function () {
      rafId = 0;
      callback(computeActiveTocId())();
    });
  }, { passive: true });
}
