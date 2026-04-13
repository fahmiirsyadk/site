/* global window, document, performance, requestAnimationFrame, cancelAnimationFrame, setTimeout, matchMedia, Math */
/**
 * Opaque red mask + punched holes (no canvas smear trail).
 * UPDATED: pauses after 2 frames for sea, then runs full 2s animation.
 */
var GFX_BOOT_MIN_MS = 2000;
window.__GFX_BOOT_MIN_MS = GFX_BOOT_MIN_MS;

(function initGfxBootCoordinator() {
  if (typeof window === "undefined") return;
  window.__gfxBoot = {
    sea: false,
    logo: false,
    dismissed: false,
    pausedForSea: false,
    animationDone: false,
    resumeAfterSea: null,
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
      if (!b || b.dismissed ||!b.logo ||!b.sea ||!b.animationDone) return;
      const el = document.getElementById("gfx-boot-overlay");
      b.dismissed = true;
      if (!el) return;
      el.setAttribute("data-state", "done");
      console.log("[boot] dismissing overlay");
      try { el.remove(); } catch (_) {}
      try {
        window.dispatchEvent(new Event("gfx-boot-dismissed"));
        console.log("[boot] dispatched gfx-boot-dismissed");
      } catch (_) {}
    },
  };
  const b = window.__gfxBoot;
  setTimeout(() => { if (!b.dismissed &&!b.sea) b.markSea(); }, 12000);
  setTimeout(() => { if (!b.dismissed &&!b.logo) b.markLogo(); }, 12000);
})();

(function startGfxBootAnim() {
  if (typeof window === "undefined" || typeof document === "undefined") return;

  const minMs = window.__GFX_BOOT_MIN_MS || 2000;

  function run() {
    const overlay = document.getElementById("gfx-boot-overlay");
    const canvas = document.getElementById("gfx-boot-canvas");
    const counterEl = document.getElementById("gfx-boot-counter");
    const progressEl = document.getElementById("gfx-boot-progress");
    if (!overlay ||!canvas ||!counterEl) return;

    const ctx = canvas.getContext("2d", { alpha: true });
    if (!ctx) return;
    canvas.style.backgroundColor = "transparent";

    let dpr = 1, W = 0, H = 0, CELL = 56, cols = 0, rows = 0, total = 0;
    const indices = [], filled = [];
    let spawned = 0, ptr = 0, rafId = 0, chromeRemoved = false, maskHolesAppended = 0;
    let bootFrame = 0;
    let hasPausedForSea = false;
    let lastCounter = -1;
    let lastProgress = -1;
    const MASK_APPEND_BATCH = 140;

    // visibility-aware timing
    let isHidden = document.hidden;
    let activeElapsed = 0;
    let lastActive = performance.now();

    function getActiveTime(now) {
      const paused = window.__gfxBoot?.pausedForSea;
      return activeElapsed + (isHidden || paused? 0 : (now - lastActive));
    }

    function onVisibility() {
      const now = performance.now();
      if (document.hidden) {
        if (!isHidden) {
          activeElapsed += now - lastActive;
          isHidden = true;
        }
        if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
      } else {
        isHidden = false;
        lastActive = now;
        if (!rafId &&!window.__gfxBoot?.pausedForSea) rafId = requestAnimationFrame(tick);
      }
    }
    document.addEventListener("visibilitychange", onVisibility, { passive: true });

    // --- SEA COORDINATION ---
    window.__gfxBoot.resumeAfterSea = () => {
      console.log("[boot] resuming after sea ready");
      window.__gfxBoot.pausedForSea = false;
      window.__gfxBoot.animationDone = false;
      lastActive = performance.now();
      chromeRemoved = false;
      overlay.style.pointerEvents = "";
      if (!rafId &&!isHidden) rafId = requestAnimationFrame(tick);
    };
    window.addEventListener("sea-ready", window.__gfxBoot.resumeAfterSea, { once: true });
    setTimeout(() => {
      if (window.__gfxBoot?.pausedForSea) {
        console.log("[boot] resume timeout fallback");
        window.__gfxBoot.resumeAfterSea();
      }
    }, 8000);

    const svgNS = "http://www.w3.org/2000/svg";

    function shuffle(arr) { for (let i = arr.length - 1; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [arr[i], arr[j]] = [arr[j], arr[i]]; } }

    function syncSize() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      const br = overlay.getBoundingClientRect();
      W = Math.max(1, Math.round(br.width));
      H = Math.max(1, Math.round(br.height));
      CELL = W < 640? 44 : 56;
      cols = Math.ceil(W / CELL) + 2;
      rows = Math.ceil(H / CELL) + 2;
      total = cols * rows;
      const bw = Math.max(1, Math.floor(W * dpr));
      const bh = Math.max(1, Math.floor(H * dpr));
      canvas.width = bw; canvas.height = bh;
      canvas.style.width = `${W}px`; canvas.style.height = `${H}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = false;
      updateChromeMaskSize();
    }

    function updateChromeMaskSize() {
      const m = document.getElementById("gfx-boot-chrome-cut-mask");
      const bg = document.getElementById("gfx-boot-mask-white");
      if (m) { m.setAttribute("x","0"); m.setAttribute("y","0"); m.setAttribute("width", String(W)); m.setAttribute("height", String(H)); }
      if (bg) { bg.setAttribute("width", String(W)); bg.setAttribute("height", String(H)); }
    }

    function clearChromeMaskHoles() {
      const g = document.getElementById("gfx-boot-mask-holes");
      if (g) g.replaceChildren();
      maskHolesAppended = 0;
    }

    function syncChromeMask() {
      const g = document.getElementById("gfx-boot-mask-holes");
      if (!g) return;
      const hole = CELL + 1;
      let appended = 0;
      while (maskHolesAppended < filled.length && appended < MASK_APPEND_BATCH) {
        const cell = filled[maskHolesAppended++];
        const r = document.createElementNS(svgNS, "rect");
        r.setAttribute("x", String(Math.floor(cell.x)));
        r.setAttribute("y", String(Math.floor(cell.y)));
        r.setAttribute("width", String(hole));
        r.setAttribute("height", String(hole));
        r.setAttribute("fill", "black");
        g.appendChild(r);
        appended++;
      }
    }

    function rebuildFillGrid() {
      indices.length = 0;
      for (let i = 0; i < total; i++) indices.push(i);
      shuffle(indices);
      ptr = 0; spawned = 0; filled.length = 0;
      clearChromeMaskHoles();
    }

    function bootFill() {
      syncSize();
      rebuildFillGrid();
      overlay.classList.remove("gfx-boot-inverted");
    }

    bootFill();

    function spawnCellsToTarget(targetCount) {
      const cap = Math.min(targetCount, total);
      while (spawned < cap && ptr < total) {
        const id = indices[ptr++];
        const c = id % cols;
        const r = (id / cols) | 0;
        const x = c * CELL - CELL;
        const y = r * CELL - CELL;
        filled.push({ x, y });
        spawned++;
      }
    }

    function syncProgressToTimeline(now) {
      const activeNow = getActiveTime(now);
      const tp = Math.min(1, activeNow / minMs);
      const counter = Math.min(50, Math.floor(tp * 50));
      if (counter !== lastCounter) {
        lastCounter = counter;
        counterEl.textContent = String(counter).padStart(2, "0");
      }
      if (progressEl) {
        const progress = Math.round(tp * 100);
        if (progress !== lastProgress) {
          lastProgress = progress;
          progressEl.textContent = `${progress}%`;
        }
      }
      const targetSpawned = tp >= 1? total : Math.floor(tp * total);
      spawnCellsToTarget(targetSpawned);
    }

    function onBootTimelineComplete() {
      if (chromeRemoved) return;
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
      const hole = CELL + 1;
      ctx.globalCompositeOperation = "destination-out";
      ctx.fillStyle = "#000000";
      for (let k = 0; k < filled.length; k++) {
        const cell = filled[k];
        ctx.fillRect(Math.floor(cell.x), Math.floor(cell.y), hole, hole);
      }
      ctx.globalCompositeOperation = "source-over";
    }

    function tick() {
      if (isHidden || window.__gfxBoot?.pausedForSea) { rafId = 0; return; }
      if (!document.body.contains(overlay) || overlay.getAttribute("data-state") === "done") {
        if (rafId) cancelAnimationFrame(rafId);
        return;
      }
      const now = performance.now();
      syncProgressToTimeline(now);
      const tp = Math.min(1, getActiveTime(now) / minMs);
      if (tp >= 1 &&!chromeRemoved) onBootTimelineComplete();
      drawMask();
      syncChromeMask();

      bootFrame++;
      if (bootFrame === 2 &&!window.__gfxBoot.pausedForSea &&!hasPausedForSea) {
        hasPausedForSea = true;
        if (!isHidden) activeElapsed += now - lastActive;
        window.__gfxBoot.pausedForSea = true;
        console.log("[boot] pausing after 2 frames for sea");
        window.dispatchEvent(new Event("gfx-boot-pause-for-sea"));
        rafId = 0;
        return;
      }

      rafId = requestAnimationFrame(tick);
    }

    const onBootViewportResize = () => {
      if (!document.body.contains(overlay) || overlay.getAttribute("data-state") === "done") return;
      if (spawned < total * 0.98) bootFill(); else syncSize();
    };
    window.addEventListener("resize", onBootViewportResize);
    if (window.visualViewport) window.visualViewport.addEventListener("resize", onBootViewportResize);

    rafId = requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", run);
  else run();
})();