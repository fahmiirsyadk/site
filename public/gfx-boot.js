/* global window, document, performance, requestAnimationFrame, cancelAnimationFrame, setTimeout, matchMedia, Math */
/**
 * Opaque red mask + punched holes (no canvas smear trail).
 * Hole expansion is driven by reported rendering progress, with a graceful time-based
 * fallback. Sea / logo / shader milestones push progress via __gfxBoot.setProgress().
 */
(function initGfxBootCoordinator() {
  if (typeof window === "undefined") return;
  /** @type {{sea:boolean,logo:boolean,dismissed:boolean,animationDone:boolean,markSea:()=>void,markLogo:()=>void,setProgress:(phase:string,percent:number)=>void,markPhase:(phase:string,percent:number)=>void,_targetProgress:number,_try:()=>void}} */
  window.__gfxBoot = {
    sea: false,
    logo: false,
    dismissed: false,
    animationDone: false,
    /** External progress 0-100 from sea/logo rendering milestones. */
    _targetProgress: 0,
    _progressPhases: {},
    setProgress(phase, percent) {
      const b = window.__gfxBoot;
      if (!b || b.dismissed || b.animationDone) return;
      b._progressPhases[phase] = percent;
      // Take the maximum reported progress across all phases.
      let maxP = 0;
      for (const k in b._progressPhases) {
        if (b._progressPhases[k] > maxP) maxP = b._progressPhases[k];
      }
      const prev = b._targetProgress;
      b._targetProgress = Math.max(0, Math.min(100, maxP));
      if (b._targetProgress !== prev) {
        console.log(
          '[boot] setProgress "' +
            phase +
            '" = ' +
            percent +
            "%  (max=" +
            b._targetProgress +
            "%)",
        );
      }
    },
    /** Shorthand: markPhase("simple_compile", 25) */
    markPhase(phase, percent) {
      const b = window.__gfxBoot;
      if (b) b.setProgress(phase, percent);
    },
    markSea() {
      const b = window.__gfxBoot;
      if (!b || b.dismissed) return;
      b.sea = true;
      b._try();
    },
    markLogo() {
      const b = window.__gfxBoot;
      if (!b || b.dismissed) return;
      b.logo = true;
      b._try();
    },
    _try() {
      const b = window.__gfxBoot;
      if (!b || b.dismissed || !b.logo || !b.sea || !b.animationDone) return;
      // Dismiss requires: sea + logo + animationDone (set only at 100% or 15s timeout).
      const el = document.getElementById("gfx-boot-overlay");
      if (!el) return;
      b.dismissed = true;
      el.setAttribute("data-state", "done");
      console.log("[boot] dismissing overlay");
      try {
        el.remove();
      } catch (_) {}
      try {
        window.dispatchEvent(new Event("gfx-boot-dismissed"));
        console.log("[boot] dispatched gfx-boot-dismissed");
      } catch (_) {}
    },
  };
  const b = window.__gfxBoot;
  setTimeout(function () {
    if (!b.dismissed && !b.sea) b.markSea();
  }, 12000);
  setTimeout(function () {
    if (!b.dismissed && !b.logo) b.markLogo();
  }, 12000);
})();

(function startGfxBootAnim() {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  function run() {
    var overlay = document.getElementById("gfx-boot-overlay");
    var canvas = document.getElementById("gfx-boot-canvas");
    var counterEl = document.getElementById("gfx-boot-counter");
    var progressEl = document.getElementById("gfx-boot-progress");
    if (!overlay || !canvas || !counterEl) return;

    var ctx = canvas.getContext("2d", { alpha: true });
    if (!ctx) return;
    canvas.style.backgroundColor = "transparent";

    var dpr = 1,
      W = 0,
      H = 0,
      CELL = 56,
      cols = 0,
      rows = 0,
      total = 0;
    var indices = [],
      filled = [];
    var spawned = 0,
      ptr = 0,
      rafId = 0,
      chromeRemoved = false,
      maskHolesAppended = 0;
    var lastCounter = -1;
    var lastProgress = -1;
    var MASK_APPEND_BATCH = 140;

    // visibility-aware timing
    var isHidden = document.hidden;
    var activeElapsed = 0;
    var lastActive = performance.now();
    var bootStartTime = lastActive;

    // Progress blending: smoothly approach targetProgress from milestones.
    var displayedProgress = 0; // 0-1, the progress rendered on screen
    var gridDisplayed = 0; // 0-1, grid holes; only starts after 100% milestone
    var progressFromMilestones = 0; // 0-1, latest from setProgress()

    function getActiveTime(now) {
      return activeElapsed + (isHidden ? 0 : now - lastActive);
    }

    function onVisibility() {
      var now = performance.now();
      if (document.hidden) {
        if (!isHidden) {
          activeElapsed += now - lastActive;
          isHidden = true;
        }
        if (rafId) {
          cancelAnimationFrame(rafId);
          rafId = 0;
        }
      } else {
        isHidden = false;
        lastActive = now;
        if (!rafId) rafId = requestAnimationFrame(tick);
      }
    }
    document.addEventListener("visibilitychange", onVisibility, {
      passive: true,
    });

    var svgNS = "http://www.w3.org/2000/svg";

    function buildCenterOutCircleOrder() {
      indices.length = 0;
      var cx = (cols - 1) / 2;
      var cy = (rows - 1) / 2;
      var ringPhase = 0.85;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          var dx = c - cx;
          var dy = r - cy;
          var dist2 = dx * dx + dy * dy;
          var radius = Math.sqrt(dist2);
          var ang = Math.atan2(dy, dx);
          var swirl = ang + radius * ringPhase;
          indices.push({ id: r * cols + c, dist2: dist2, swirl: swirl });
        }
      }
      indices.sort(function (a, b) {
        if (a.dist2 !== b.dist2) return a.dist2 - b.dist2;
        return a.swirl - b.swirl;
      });
    }

    function syncSize() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      var br = overlay.getBoundingClientRect();
      W = Math.max(1, Math.round(br.width));
      H = Math.max(1, Math.round(br.height));
      CELL = W < 640 ? 44 : 56;
      cols = Math.ceil(W / CELL) + 2;
      rows = Math.ceil(H / CELL) + 2;
      total = cols * rows;
      var bw = Math.max(1, Math.floor(W * dpr));
      var bh = Math.max(1, Math.floor(H * dpr));
      canvas.width = bw;
      canvas.height = bh;
      canvas.style.width = W + "px";
      canvas.style.height = H + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = false;
      updateChromeMaskSize();
    }

    function updateChromeMaskSize() {
      var m = document.getElementById("gfx-boot-chrome-cut-mask");
      var bg = document.getElementById("gfx-boot-mask-white");
      if (m) {
        m.setAttribute("x", "0");
        m.setAttribute("y", "0");
        m.setAttribute("width", String(W));
        m.setAttribute("height", String(H));
      }
      if (bg) {
        bg.setAttribute("width", String(W));
        bg.setAttribute("height", String(H));
      }
    }

    function clearChromeMaskHoles() {
      var g = document.getElementById("gfx-boot-mask-holes");
      if (g) g.replaceChildren();
      maskHolesAppended = 0;
    }

    function syncChromeMask() {
      var g = document.getElementById("gfx-boot-mask-holes");
      if (!g) return;
      var hole = CELL;
      var appended = 0;
      var frag = document.createDocumentFragment();
      while (
        maskHolesAppended < filled.length &&
        appended < MASK_APPEND_BATCH
      ) {
        var cell = filled[maskHolesAppended++];
        var r = document.createElementNS(svgNS, "rect");
        r.setAttribute("x", String(Math.floor(cell.x)));
        r.setAttribute("y", String(Math.floor(cell.y)));
        r.setAttribute("width", String(hole));
        r.setAttribute("height", String(hole));
        r.setAttribute("fill", "black");
        frag.appendChild(r);
        appended++;
      }
      if (appended) g.appendChild(frag);
    }

    function rebuildFillGrid() {
      buildCenterOutCircleOrder();
      ptr = 0;
      spawned = 0;
      filled.length = 0;
      clearChromeMaskHoles();
      gridDisplayed = 0;
    }

    function bootFill() {
      syncSize();
      rebuildFillGrid();
      overlay.classList.remove("gfx-boot-inverted");
    }

    bootFill();

    function spawnCellsToTarget(targetCount) {
      var cap = Math.min(targetCount, total);
      while (spawned < cap && ptr < total) {
        var id = indices[ptr++].id;
        var c = id % cols;
        var r = (id / cols) | 0;
        var x = c * CELL - CELL;
        var y = r * CELL - CELL;
        filled.push({ x: x, y: y });
        spawned++;
      }
    }

    /**
     * Compute effective progress (0-1) purely from shader milestones.
     * A very slow drift (0.5%/s) kicks in only after 3s of no milestone
     * updates, just to avoid appearing completely frozen.
     */
    var lastMilestoneChange = 0;
    var lastMilestoneValue = 0;
    function computeEffectiveProgress(now) {
      var activeNow = getActiveTime(now);

      // Read latest milestone progress (0-100 → 0-1).
      var bp = window.__gfxBoot ? window.__gfxBoot._targetProgress || 0 : 0;
      progressFromMilestones = bp / 100;

      // Track when the milestone last changed.
      if (bp !== lastMilestoneValue) {
        if (lastMilestoneValue !== bp) {
          console.log(
            "[boot] milestone " +
              lastMilestoneValue +
              "% → " +
              bp +
              "%  (active=" +
              activeNow.toFixed(0) +
              "ms)",
          );
        }
        lastMilestoneChange = activeNow;
        lastMilestoneValue = bp;
      }

      // Effective target = milestone progress.
      // After 3s with no milestone updates, add a very slow drift (0.5%/s).
      var effectiveTarget = progressFromMilestones;
      var stuckDuration = activeNow - lastMilestoneChange;
      if (stuckDuration > 3000) {
        var drift = (stuckDuration - 3000) * 0.0005; // 0.5% per second
        effectiveTarget = Math.min(1, progressFromMilestones + drift);
      }

      // Log on significant changes.
      if (Math.abs(effectiveTarget - displayedProgress) > 0.03) {
        console.log(
          "[boot] effectiveTarget=" +
            (effectiveTarget * 100).toFixed(0) +
            "%  milestone=" +
            (progressFromMilestones * 100).toFixed(0) +
            "%  displayed=" +
            (displayedProgress * 100).toFixed(0) +
            "%  stuck=" +
            stuckDuration.toFixed(0) +
            "ms",
        );
      }

      return effectiveTarget;
    }

    function syncProgressToTimeline(now) {
      var ep = computeEffectiveProgress(now);

      // Smooth monotonic approach toward effective target (drives counter/text).
      if (ep > displayedProgress) {
        displayedProgress += (ep - displayedProgress) * 0.12;
      }
      if (Math.abs(ep - displayedProgress) < 0.001) displayedProgress = ep;
      var dp = Math.min(1, displayedProgress);

      var counter = Math.min(50, Math.floor(dp * 50));
      if (counter !== lastCounter) {
        lastCounter = counter;
        counterEl.textContent = String(counter).padStart(2, "0");
      }
      if (progressEl) {
        var progress = Math.round(dp * 100);
        if (progress !== lastProgress) {
          lastProgress = progress;
          progressEl.textContent = progress + "%";
        }
      }

      // Grid holes only open after the full first frame reports 100%.
      // Before that the overlay stays solid so users don't see partial/compiling content.
      var bp = window.__gfxBoot ? window.__gfxBoot._targetProgress || 0 : 0;
      if (bp >= 100) {
        if (ep > gridDisplayed) {
          gridDisplayed += (ep - gridDisplayed) * 0.12;
        }
        if (Math.abs(ep - gridDisplayed) < 0.001) gridDisplayed = ep;
      }
      var gdp = Math.min(1, gridDisplayed);
      var targetSpawned = gdp >= 1 ? total : Math.floor(gdp * total);
      spawnCellsToTarget(targetSpawned);
    }

    function onBootTimelineComplete() {
      if (chromeRemoved) return;
      console.log(
        "[boot] completing overlay (elapsed=" +
          (performance.now() - bootStartTime).toFixed(0) +
          "ms)",
      );
      chromeRemoved = true;
      overlay.style.pointerEvents = "none";
      window.__gfxBoot.animationDone = true;
      window.__gfxBoot._try();
    }

    function drawMask() {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = false;
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = "#FF0000";
      ctx.fillRect(0, 0, W, H);
      // Draw holes with 1px overlap to prevent red subpixel gaps between adjacent tiles.
      var hole = CELL;
      ctx.globalCompositeOperation = "destination-out";
      ctx.fillStyle = "#000000";
      for (var k = 0; k < filled.length; k++) {
        var cell = filled[k];
        ctx.fillRect(
          Math.floor(cell.x) - 1,
          Math.floor(cell.y) - 1,
          hole + 2,
          hole + 2,
        );
      }
      ctx.globalCompositeOperation = "source-over";
    }

    function tick() {
      if (isHidden) {
        rafId = 0;
        return;
      }
      if (
        !document.body.contains(overlay) ||
        overlay.getAttribute("data-state") === "done"
      ) {
        if (rafId) cancelAnimationFrame(rafId);
        return;
      }
      var now = performance.now();
      syncProgressToTimeline(now);
      // Hard timeout: force the grid fully open at 15 s so the overlay is never stuck.
      if (now >= bootStartTime + 15000 && gridDisplayed < 1) {
        gridDisplayed = 1;
        spawnCellsToTarget(total);
      }
      if (gridDisplayed >= 0.995 && !chromeRemoved) {
        onBootTimelineComplete();
      }
      drawMask();
      syncChromeMask();
      rafId = requestAnimationFrame(tick);
    }

    var onBootViewportResize = function () {
      if (
        !document.body.contains(overlay) ||
        overlay.getAttribute("data-state") === "done"
      )
        return;
      if (spawned < total * 0.98) bootFill();
      else syncSize();
    };
    window.addEventListener("resize", onBootViewportResize);
    if (window.visualViewport)
      window.visualViewport.addEventListener("resize", onBootViewportResize);

    rafId = requestAnimationFrame(tick);
  }

  if (document.readyState === "loading")
    document.addEventListener("DOMContentLoaded", run);
  else run();
})();
