// FFI bindings — consolidated browser/DOM/platform-layer JS for the site.
// Each export corresponds to a `foreign import` in `FFI.purs`.
// Sections: DOM | Theme | Scroll/TOC | Route/Links | Island Delegation | Measure | RelativeTime

/* ------------------------------------------------------------------ */
/*  DOM / Browser primitives                                           */
/* ------------------------------------------------------------------ */

export const runWhenIdle = (eff) => () => {
  const go = () => { try { eff(); } catch (e) { console.warn("[runWhenIdle]", e); } };
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(go, { timeout: 2800 });
  } else {
    requestAnimationFrame(() => { setTimeout(go, 0); });
  }
};

export const afterPaint = (eff) => () => requestAnimationFrame(() => eff());

export const everyMsInterval = (ms) => (eff) => () => setInterval(() => eff(), ms);

export const fetchText = (url) => (onOk) => (onErr) => () => {
  fetch(url)
    .then((r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.text(); })
    .then((t) => onOk(t)())
    .catch((e) => onErr(String(e))());
};

/* ------------------------------------------------------------------ */
/*  Theme                                                              */
/* ------------------------------------------------------------------ */

const THEME_STORAGE_KEY = "theme";
const getStoredMode = () => {
  try { const s = localStorage.getItem(THEME_STORAGE_KEY); return s === "dark" ? "dark" : "light"; }
  catch { return "light"; }
};
const effectiveDark = (m) => m === "dark";

export const getStoredThemeMode = () => getStoredMode();

export const applyThemeMode = (mode) => () => {
  try { localStorage.setItem(THEME_STORAGE_KEY, mode); } catch {}
  document.documentElement.classList.toggle("dark", effectiveDark(mode));
  try { document.documentElement.style.colorScheme = effectiveDark(mode) ? "dark" : "light"; } catch {}
};

export const patchSsrThemeButtons = (mode) => () => {
  const map = new Map([["Use light theme", "light"], ["Use dark theme", "dark"]]);
  document.querySelectorAll("[data-theme-controls] button[aria-label]").forEach((btn) => {
    const m = map.get(btn.getAttribute("aria-label"));
    if (m) btn.setAttribute("aria-pressed", m === mode ? "true" : "false");
  });
};

/* ------------------------------------------------------------------ */
/*  Scroll / Anchor / TOC                                              */
/* ------------------------------------------------------------------ */

export function scrollToHashIdImpl(id) {
  if (!id) return;
  const target = document.getElementById(id);
  if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
}

function isMobileTocViewport() {
  try { return typeof matchMedia !== "undefined" && matchMedia("(max-width: 767px)").matches; }
  catch (_) { return false; }
}

function computeActiveTocId() {
  var links = Array.from(document.querySelectorAll("a[data-toc-id]"));
  var seen = Object.create(null);
  var ids = [];
  for (var j = 0; j < links.length; j++) {
    var id = links[j].getAttribute("data-toc-id");
    if (id && !seen[id]) { seen[id] = true; ids.push(id); }
  }
  if (ids.length === 0) return null;

  var headings = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
  if (headings.length === 0) return null;

  var nav = document.querySelector("nav.mobile-site-nav");
  var navH = 0;
  if (nav) { var r = nav.getBoundingClientRect(); navH = r.bottom > 0 ? r.bottom : 0; }
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
    if (isMobileTocViewport()) return;
    callback(computeActiveTocId())();
  };

  el._siteTocSpyTick = run;

  el.addEventListener("scroll", function () {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(function () { rafId = 0; run(); });
  }, { passive: true });

  requestAnimationFrame(run);
  window.addEventListener("resize", function () {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = requestAnimationFrame(function () { rafId = 0; run(); });
  }, { passive: true });
}

export function tickScrollSpyImpl(containerId) {
  var el = document.getElementById(containerId);
  if (!el || typeof el._siteTocSpyTick !== "function") return;
  el._siteTocSpyTick();
}

/* ------------------------------------------------------------------ */
/*  Route / Link interception                                          */
/* ------------------------------------------------------------------ */

export function interceptLinksImpl(appNode, onNavigate, onHashNavigate) {
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  const runNavigation = function (fullPath) {
    window.history.pushState(null, "", fullPath);
    onNavigate(fullPath)();
  };

  const runHashNavigation = function (id) {
    if (!id) return;
    window.history.replaceState(null, "", `${window.location.pathname}#${id}`);
    requestAnimationFrame(function () {
      const target = document.getElementById(id);
      if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    onHashNavigate(id)();
  };

  const handler = function (e) {
    if (e.defaultPrevented) return;
    if (e.button !== 0) return;
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const target = e.target;
    if (!(target instanceof Element)) return;
    const link = target.closest("a[href]");
    if (!link) return;
    if (link.target === "_blank") return;
    if (link.hasAttribute("download")) return;
    const href = link.getAttribute("href");
    if (!href) return;
    if (href.startsWith("#")) { e.preventDefault(); runHashNavigation(href.slice(1)); return; }
    const url = new URL(link.href, window.location.origin);
    if (url.origin !== window.location.origin) return;
    e.preventDefault();
    const fullPath = url.pathname + url.search + url.hash;
    if (document.startViewTransition && !prefersReducedMotion.matches) {
      document.startViewTransition(function () { runNavigation(fullPath); });
      return;
    }
    runNavigation(fullPath);
  };

  appNode.addEventListener("click", handler);
  return function () { appNode.removeEventListener("click", handler); };
}

/* ------------------------------------------------------------------ */
/*  Island delegation (tool cards, terminal, copy)                     */
/* ------------------------------------------------------------------ */

let markdownBound = false;

export const initMarkdownProseDelegation = (appNode) => () => {
  if (!appNode || markdownBound) return;
  markdownBound = true;
  appNode.addEventListener("click", (e) => {
    const toolBtn = e.target.closest("[data-tool-display-toggle]");
    if (toolBtn) {
      const card = toolBtn.closest('[data-component="tool-display-card"]');
      if (card && !card.classList.contains("terminal-card")) {
        const was = toolBtn.getAttribute("aria-expanded") === "true";
        toolBtn.setAttribute("aria-expanded", String(!was));
        card.classList.toggle("is-expanded", !was);
        e.preventDefault();
        return;
      }
    }
    const tToggle = e.target.closest("[data-terminal-toggle]");
    if (tToggle) {
      const id = tToggle.dataset.target;
      const body = document.getElementById(id);
      const was = tToggle.getAttribute("aria-expanded") === "true";
      tToggle.setAttribute("aria-expanded", String(!was));
      if (body) body.hidden = was;
      e.preventDefault();
      return;
    }
    const tCopy = e.target.closest("[data-terminal-copy]");
    if (tCopy) {
      navigator.clipboard?.writeText(tCopy.dataset.command || "").catch(() => {});
      tCopy.setAttribute("title", "Copied");
      setTimeout(() => tCopy.setAttribute("title", "Copy"), 900);
      e.preventDefault();
    }
  });
};

/* ------------------------------------------------------------------ */
/*  Tool card measurement                                              */
/* ------------------------------------------------------------------ */

const TOOL_DISPLAY_COLLAPSED_MAX_PX = 200;

export const measureToolCards = (cb) => () => {
  document
    .querySelectorAll('[data-component="tool-display-card"][data-block-id]:not(.terminal-card)')
    .forEach((card) => {
      const id = card.dataset.blockId, body = card.querySelector(".tool-display-body");
      if (!id || !body) return;
      const prev = body.style.maxHeight;
      body.style.maxHeight = "none";
      const h = body.scrollHeight;
      body.style.maxHeight = prev;
      cb(id)(h)();
      const luna = card.getAttribute("data-measured-island") === "true";
      if (!luna) {
        const btn = card.querySelector(".tool-display-expand-btn");
        if (h <= TOOL_DISPLAY_COLLAPSED_MAX_PX + 1) {
          card.classList.add("tool-display-card--no-expand");
          card.classList.remove("is-expanded");
          btn?.setAttribute("aria-expanded", "false");
        } else {
          card.classList.remove("tool-display-card--no-expand");
          card.classList.add("is-expanded");
          btn?.setAttribute("aria-expanded", "true");
        }
      }
    });
};

/* ------------------------------------------------------------------ */
/*  Relative time / date                                               */
/* ------------------------------------------------------------------ */

const minuteMs = 60000;
const hourMs = 3600000;
const dayMs = 86400000;
const weekMs = 604800000;
const monthMs = 2592000000;
const yearMs = 31536000000;

let rtf = null;
function getRtf() {
  if (!rtf) { rtf = new Intl.RelativeTimeFormat(undefined, { numeric: "auto", style: "short" }); }
  return rtf;
}

function formatAgo(ms) {
  if (ms < 0) return "soon";
  if (ms < minuteMs) return "just now";
  if (ms < hourMs) return getRtf().format(-Math.round(ms / minuteMs), "minute");
  if (ms < dayMs) return getRtf().format(-Math.round(ms / hourMs), "hour");
  if (ms < weekMs) return getRtf().format(-Math.round(ms / dayMs), "day");
  if (ms < monthMs) return getRtf().format(-Math.round(ms / weekMs), "week");
  if (ms < yearMs) return getRtf().format(-Math.round(ms / monthMs), "month");
  return getRtf().format(-Math.round(ms / yearMs), "year");
}

export const parseIsoToMillis = (s) => {
  const t = Date.parse(s);
  return Number.isNaN(t) ? -1 : t;
};

export const patchRelativeDates = () => {
  const now = Date.now();
  document.querySelectorAll("[data-relative-date]").forEach((el) => {
    const iso = el.getAttribute("data-relative-date");
    if (!iso) return;
    const t = parseIsoToMillis(iso);
    if (t < 0) return;
    const label = formatAgo(now - t);
    if (el.textContent !== label) el.textContent = label;
  });
};
