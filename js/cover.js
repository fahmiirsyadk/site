/* cover.js -- article cover effect: render the banner image as an ordered-dither
   duotone (two colors only) matching the site's pixelated/dithered aesthetic.

   Each `.cover-scene` sits over the cover <img> (the fallback). We draw that image
   into a low-res canvas (cover-fit), then map every pixel to one of two colors via
   an 8x8 Bayer threshold on luminance: highlights -> --duotone-light (white),
   shadows -> --duotone-dark (accent orange). The canvas is upscaled with
   image-rendering: pixelated for crisp dither dots.

   Static (no animation); recomputed on resize and on light/dark theme change. */
(function () {
  "use strict";
  if (typeof window === "undefined" || typeof document === "undefined") return;

  // 8x8 Bayer ordered-dither matrix, values 0..63.
  var BAYER = [
    0, 32, 8, 40, 2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44, 4, 36, 14, 46, 6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
    3, 35, 11, 43, 1, 33, 9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7, 39, 13, 45, 5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
  ];

  // Pixels per dither dot (cover is rendered at 1/CELL resolution, then upscaled).
  var CELL = 2;

  function hexToRgb(hex) {
    hex = (hex || "").trim().replace("#", "");
    if (hex.length === 3) hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    var n = parseInt(hex.slice(0, 6), 16);
    return [n >> 16 & 255, n >> 8 & 255, n & 255];
  }
  function cssColor(name, dflt) {
    var v = getComputedStyle(document.documentElement).getPropertyValue(name);
    return hexToRgb(v && v.trim() ? v : dflt);
  }

  function mountScene(scene) {
    if (scene.dataset.init === "true") return;
    var img = scene.parentNode && scene.parentNode.querySelector("img");
    if (!img) return;

    var canvas = document.createElement("canvas");
    canvas.className = "cover-canvas";
    var ctx = canvas.getContext("2d");
    if (!ctx) return;
    scene.appendChild(canvas);
    scene.dataset.init = "true";

    var dark, light;
    function readColors() {
      dark = cssColor("--duotone-dark", "#ff4b26");
      light = cssColor("--duotone-light", "#ffffff");
    }

    function render() {
      if (!img.complete || !img.naturalWidth) return;
      var r = scene.getBoundingClientRect();
      var cssW = Math.max(1, Math.round(r.width)), cssH = Math.max(1, Math.round(r.height));
      var W = Math.max(1, Math.round(cssW / CELL)), H = Math.max(1, Math.round(cssH / CELL));
      canvas.width = W; canvas.height = H;
      canvas.style.width = cssW + "px"; canvas.style.height = cssH + "px";

      // object-fit: cover — crop the image to the canvas aspect ratio.
      var iw = img.naturalWidth, ih = img.naturalHeight;
      var ir = iw / ih, cr = W / H, sw, sh, sx, sy;
      if (ir > cr) { sh = ih; sw = ih * cr; sx = (iw - sw) / 2; sy = 0; }
      else { sw = iw; sh = iw / cr; sx = 0; sy = (ih - sh) / 2; }
      ctx.clearRect(0, 0, W, H);
      ctx.drawImage(img, sx, sy, sw, sh, 0, 0, W, H);

      var data;
      try { data = ctx.getImageData(0, 0, W, H); } catch (e) { return; } // tainted (cross-origin)
      var d = data.data;
      var dr = dark[0], dg = dark[1], db = dark[2];
      var lr = light[0], lg = light[1], lb = light[2];
      for (var y = 0; y < H; y++) {
        for (var x = 0; x < W; x++) {
          var i = (y * W + x) * 4;
          var luma = (d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114) / 255;
          var th = (BAYER[(y & 7) * 8 + (x & 7)] + 0.5) / 64;
          if (luma > th) { d[i] = lr; d[i + 1] = lg; d[i + 2] = lb; }
          else { d[i] = dr; d[i + 1] = dg; d[i + 2] = db; }
          d[i + 3] = 255;
        }
      }
      ctx.putImageData(data, 0, 0);
    }

    readColors();
    if (img.complete && img.naturalWidth) render();
    else img.addEventListener("load", render, { once: true });

    if (typeof ResizeObserver !== "undefined") new ResizeObserver(render).observe(scene);
    if (typeof MutationObserver !== "undefined") {
      new MutationObserver(function () { readColors(); render(); })
        .observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
    }
  }

  function init() {
    var scenes = document.querySelectorAll(".cover-scene");
    for (var i = 0; i < scenes.length; i++) mountScene(scenes[i]);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init, { once: true });
  else init();

  // Re-scan after SPA soft-navigations insert a new cover into #page-view.
  window.__coverInit = init;
})();
