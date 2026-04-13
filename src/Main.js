/* global window, document, performance, requestAnimationFrame, cancelAnimationFrame, setTimeout, matchMedia, Math */
const SEA_FRAG_URL = "/assets/shaders/sea-footer.min.frag";

export const gfxBootCheckNoCubeHosts = () => {
  try {
    if (document.querySelectorAll("[data-cube-logo-host]").length === 0) {
      window.__gfxBoot?.markLogo();
    }
  } catch (_) {}
};

export const everyMsInterval = (ms) => (eff) => () => setInterval(() => eff(), ms);
export const afterPaint = (eff) => () => requestAnimationFrame(() => eff());
export const fetchText = (url) => (onOk) => (onErr) => () => {
  fetch(url).then(r => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.text(); })
   .then(t => onOk(t)()).catch(e => onErr(String(e))());
};

const THEME_STORAGE_KEY = "theme";
const getStoredMode = () => { try { const s = localStorage.getItem(THEME_STORAGE_KEY); return s === "dark" ? "dark" : "light"; } catch { return "light"; } };
const effectiveDark = (m) => m === "dark";

const TOOL_DISPLAY_COLLAPSED_MAX_PX = 200;
export const measureToolCards = (cb) => () => {
  document.querySelectorAll('[data-component="tool-display-card"][data-block-id]:not(.terminal-card)').forEach(card => {
    const id = card.dataset.blockId, body = card.querySelector(".tool-display-body"); if (!id||!body) return;
    const prev = body.style.maxHeight; body.style.maxHeight="none"; const h=body.scrollHeight; body.style.maxHeight=prev; cb(id)(h)();
    const luna = card.getAttribute("data-measured-island")==="true";
    if (!luna) {
      const btn = card.querySelector(".tool-display-expand-btn");
      if (h <= TOOL_DISPLAY_COLLAPSED_MAX_PX+1) { card.classList.add("tool-display-card--no-expand"); card.classList.remove("is-expanded"); btn?.setAttribute("aria-expanded","false"); }
      else { card.classList.remove("tool-display-card--no-expand"); card.classList.add("is-expanded"); btn?.setAttribute("aria-expanded","true"); }
    }
  });
};

let markdownBound = false;
export const initMarkdownProseDelegation = (appNode) => () => {
  if (!appNode || markdownBound) return; markdownBound = true;
  appNode.addEventListener("click", e => {
    const toolBtn = e.target.closest("[data-tool-display-toggle]");
    if (toolBtn) { const card = toolBtn.closest('[data-component="tool-display-card"]'); if (card &&!card.classList.contains("terminal-card")) { const was = toolBtn.getAttribute("aria-expanded")==="true"; toolBtn.setAttribute("aria-expanded", String(!was)); card.classList.toggle("is-expanded",!was); e.preventDefault(); return; } }
    const tToggle = e.target.closest("[data-terminal-toggle]");
    if (tToggle) { const id=tToggle.dataset.target; const body=document.getElementById(id); const was=tToggle.getAttribute("aria-expanded")==="true"; tToggle.setAttribute("aria-expanded",String(!was)); if(body) body.hidden=was; e.preventDefault(); return; }
    const tCopy = e.target.closest("[data-terminal-copy]");
    if (tCopy) { navigator.clipboard?.writeText(tCopy.dataset.command||"").catch(()=>{}); tCopy.setAttribute("title","Copied"); setTimeout(()=>tCopy.setAttribute("title","Copy"),900); e.preventDefault(); }
  });
};

export const getStoredThemeMode = () => getStoredMode();
export const applyThemeMode = (mode) => () => { try{localStorage.setItem(THEME_STORAGE_KEY,mode);}catch{} document.documentElement.classList.toggle("dark",effectiveDark(mode)); try{document.documentElement.style.colorScheme=effectiveDark(mode)?"dark":"light";}catch{} };
export const patchSsrThemeButtons = (mode) => () => {
  const map = new Map([["Use light theme","light"],["Use dark theme","dark"]]);
  document.querySelectorAll("[data-theme-controls] button[aria-label]").forEach(btn=>{ const m=map.get(btn.getAttribute("aria-label")); if(m) btn.setAttribute("aria-pressed",m===mode?"true":"false"); });
};

/** iOS Safari: `requestIdleCallback` is often missing or may not run before navigation; always bound `fn` to one invocation. */
function scheduleHeavyGpuWork(fn) {
  let ran = false;
  const run = () => { if (ran) return; ran = true; fn(); };
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(() => run(), { timeout: 2800 });
    setTimeout(run, 4500);
  } else {
    requestAnimationFrame(() => setTimeout(run, 0));
  }
}

function seaDebugOn() {
  try {
    if (typeof sessionStorage !== "undefined" && sessionStorage.getItem("sea-debug") === "1") return true;
    return typeof location !== "undefined" && /(?:^|[?&])sea-debug=1(?:&|$)/.test(location.search);
  } catch (_) { return false; }
}

/** Readable on the phone when `?sea-debug=1` — no Mac / Safari remote inspect needed. */
function renderSeaDebugHud() {
  if (!seaDebugOn()) return;
  let el = document.getElementById("sea-debug-hud");
  if (!el) {
    el = document.createElement("pre");
    el.id = "sea-debug-hud";
    el.setAttribute("aria-live", "polite");
    el.setAttribute("aria-label", "Sea WebGL debug");
    el.style.cssText = "position:fixed;left:0;right:0;bottom:0;max-height:42vh;overflow:auto;margin:0;padding:10px 12px;padding-bottom:max(12px,env(safe-area-inset-bottom,0px));font:11px/1.4 ui-monospace,monospace;background:#111827;color:#f3f4f6;border-top:3px solid #f59e0b;z-index:2147483646;white-space:pre-wrap;word-break:break-word;";
    document.body.appendChild(el);
  }
  const r = window.__seaMountResult;
  if (!r) {
    el.textContent = "(no sea mount data yet)";
    return;
  }
  const lines = [
    "ok: " + String(r.ok),
    "fail: " + (r.fail != null ? r.fail : ""),
    "ua: " + (r.ua || ""),
    "webgl2Probe: " + String(r.webgl2Probe),
    "fragmentChars: " + String(r.fragmentChars ?? ""),
    "contextAttrsIndex: " + String(r.contextAttrsIndex ?? ""),
    "",
  ];
  if (r.vertexLog) lines.push("--- vertex shader log ---", r.vertexLog, "");
  if (r.fragmentLog) lines.push("--- fragment shader log ---", r.fragmentLog, "");
  if (r.programLog) lines.push("--- program link log ---", r.programLog, "");
  if (r.fetchError) lines.push("--- fetch ---", r.fetchError, "");
  el.textContent = lines.join("\n");
}

function webgl2ProbeCached() {
  if (typeof window === "undefined") return false;
  if (window.__seaWebgl2ProbeDone) return window.__seaWebgl2ProbeVal;
  let p = false;
  try {
    const c = document.createElement("canvas");
    p = !!c.getContext("webgl2");
  } catch (_) {}
  window.__seaWebgl2ProbeDone = true;
  window.__seaWebgl2ProbeVal = p;
  return p;
}

function setSeaMountResult(patch) {
  const ua = typeof navigator !== "undefined" ? navigator.userAgent || "" : "";
  window.__seaMountResult = Object.assign(
    { t: Date.now(), ua, webgl2Probe: webgl2ProbeCached() },
    window.__seaMountResult || {},
    patch
  );
  renderSeaDebugHud();
}

/** Prefer default GPU on mobile; iOS can return null or flaky contexts with only `high-performance`. */
function getWebGL2ContextForSea(canvas) {
  const bases = [
    { alpha: true, premultipliedAlpha: false, antialias: false, powerPreference: "default" },
    { alpha: true, premultipliedAlpha: false, antialias: false, powerPreference: "high-performance" },
    { alpha: true, premultipliedAlpha: true, antialias: false, powerPreference: "default" },
    { alpha: true, premultipliedAlpha: true, antialias: true, powerPreference: "default" },
  ];
  for (let i = 0; i < bases.length; i++) {
    const gl = canvas.getContext("webgl2", bases[i]);
    if (gl) {
      setSeaMountResult({ contextAttrsIndex: i });
      if (seaDebugOn()) console.log("[sea] WebGL2 context ok, attrs index", i, bases[i]);
      return gl;
    }
  }
  return null;
}

let seaReadySignaled = false;
function signalSeaReadyOnce(canvas, ok, detail, diagExtra) {
  if (seaReadySignaled) return;
  seaReadySignaled = true;
  if (ok) {
    delete canvas.dataset.seaFooterError;
    delete canvas.dataset.seaFooterFail;
    setSeaMountResult(Object.assign({ ok: true, fail: null }, diagExtra || {}));
  } else {
    const msg = detail || "unknown";
    canvas.dataset.seaFooterError = "1";
    canvas.dataset.seaFooterFail = msg;
    console.error("[sea] mount failed:", msg);
    setSeaMountResult(Object.assign({ ok: false, fail: msg }, diagExtra || {}));
  }
  window.dispatchEvent(new Event("sea-ready"));
  window.__gfxBoot?.markSea();
}

/** --- SEA: start during boot pause --- */
let seaStarted = false;
function startSeaDuringBootPause() {
  if (seaStarted) return; seaStarted = true;
  console.log("[sea] starting compile during boot pause");
  scheduleHeavyGpuWork(runMountSeaFooter);
}
if (typeof window!== "undefined") {
  window.addEventListener("gfx-boot-pause-for-sea", startSeaDuringBootPause, { once: true });
}
export const mountSeaFooter = () => {
  console.log("[sea] mountSeaFooter called");
  if (window.__gfxBoot?.pausedForSea || !document.getElementById("gfx-boot-overlay")) startSeaDuringBootPause();
};

function runMountSeaFooter() {
  console.log("[sea] runMountSeaFooter START");
  const canvas = document.getElementById("sea-canvas");
  if (!canvas) return;
  if (canvas.dataset.seaFooterInit === "1") return;
  canvas.dataset.seaFooterInit = "1";
  fetch(SEA_FRAG_URL)
    .then((r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.text(); })
    .then((t) => initSeaFooterWithFragment(canvas, t.trim()))
    .catch((e) => {
      console.warn("[sea] fragment fetch failed", e);
      const em = e && e.message ? e.message : String(e);
      signalSeaReadyOnce(canvas, false, "fetch:" + em, { fetchError: em });
    });
}

function initSeaFooterWithFragment(canvas, src) {
  if (!src) {
    signalSeaReadyOnce(canvas, false, "empty-fragment", { fragmentChars: 0 });
    return;
  }
  setSeaMountResult({ fragmentChars: src.length });
  if (seaDebugOn()) console.log("[sea] init fragment chars=" + src.length);

  const gl = getWebGL2ContextForSea(canvas);
  if (!gl) {
    console.warn("[sea] no WebGL2 context (iOS needs 15+; check Settings → Safari → Advanced → Experimental features)");
    signalSeaReadyOnce(canvas, false, "no-webgl2");
    return;
  }
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.enable(gl.SCISSOR_TEST);

  const mqCoarse = matchMedia?.("(pointer: coarse)");
  const mqNarrow = matchMedia?.("(max-width: 768px)");
  const narrow = mqNarrow?.matches;
  const coarse = (mqCoarse?.matches) || narrow || navigator.maxTouchPoints > 0;
  const saveData = navigator.connection?.saveData;

  const applySize = () => {
    const r = canvas.getBoundingClientRect();
    const dpr = Math.min(devicePixelRatio || 1, saveData ? 1 : narrow ? 2 : coarse ? 1.28 : 2);
    canvas.width = Math.max(1, Math.ceil(r.width * dpr));
    canvas.height = Math.max(1, Math.ceil(r.height * dpr));
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.scissor(0, 0, canvas.width, canvas.height);
  };
  applySize();
  new ResizeObserver(applySize).observe(canvas);

  const vs = "#version 300 es\nvoid main(){vec2 v=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(v*2.-1.,0,1);}";
  const seaDiag = { vertexLog: "", fragmentLog: "", programLog: "" };
  function compileStage(type, source, label) {
    const sh = gl.createShader(type);
    gl.shaderSource(sh, source);
    gl.compileShader(sh);
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
      const log = gl.getShaderInfoLog(sh) || "(no log)";
      console.error("[sea] " + label + " compile failed:\n" + log);
      if (type === gl.VERTEX_SHADER) seaDiag.vertexLog = log;
      else seaDiag.fragmentLog = log;
      gl.deleteShader(sh);
      return null;
    }
    return sh;
  }

  const vsh = compileStage(gl.VERTEX_SHADER, vs, "vertex");
  const fsh = compileStage(gl.FRAGMENT_SHADER, src, "fragment");
  if (!vsh || !fsh) {
    signalSeaReadyOnce(canvas, false, "shader-compile", {
      vertexLog: seaDiag.vertexLog,
      fragmentLog: seaDiag.fragmentLog,
    });
    return;
  }

  const prog = gl.createProgram();
  gl.attachShader(prog, vsh);
  gl.attachShader(prog, fsh);
  gl.linkProgram(prog);
  gl.deleteShader(vsh);
  gl.deleteShader(fsh);

  let finished = false;
  const ext = gl.getExtension("KHR_parallel_shader_compile");
  const pollDeadline = performance.now() + 14000;
  let pollRaf = 0;

  function finalize() {
    if (finished) return;
    finished = true;
    if (pollRaf) cancelAnimationFrame(pollRaf);

    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      const log = gl.getProgramInfoLog(prog) || "(no log)";
      console.error("[sea] program link failed:\n" + log);
      signalSeaReadyOnce(canvas, false, "link-failed", { programLog: log });
      return;
    }

    gl.useProgram(prog);
    const uT = gl.getUniformLocation(prog, "t");
    const uR = gl.getUniformLocation(prog, "r");
    const uOff = gl.getUniformLocation(prog, "cubeOff");
    const uVel = gl.getUniformLocation(prog, "cubeVel");
    const uQ = gl.getUniformLocation(prog, "cloudQ");
    const uDark = gl.getUniformLocation(prog, "uiDark");
    const uIntro = gl.getUniformLocation(prog, "seaIntro");
    console.log("[sea] shaderReady = true");
    signalSeaReadyOnce(canvas, true, "", { programLog: "" });

    let offX = 0, offY = 0, targX = 0, targY = 0, vx = 0, vy = 0, svx = 0, svy = 0, px = 0, py = 0, drag = false, dsx = 0, dsy = 0, dbx = 0, dby = 0;
    const down = (x, y) => { drag = true; dsx = x; dsy = y; dbx = targX; dby = targY; };
    const move = (x, y) => {
      if (!drag) return;
      const r = canvas.getBoundingClientRect();
      targX = Math.max(-7, Math.min(7, dbx + ((x - dsx) / r.width) * 10));
      targY = Math.max(0, Math.min(11, dby - ((y - dsy) / r.height) * 8));
    };
    const up = () => { drag = false; };
    canvas.addEventListener("mousedown", (e) => { down(e.clientX, e.clientY); e.preventDefault(); });
    window.addEventListener("mousemove", (e) => move(e.clientX, e.clientY));
    window.addEventListener("mouseup", up);
    canvas.addEventListener("touchstart", (e) => { const t = e.touches[0]; down(t.clientX, t.clientY); e.preventDefault(); }, { passive: false });
    window.addEventListener("touchmove", (e) => { if (drag) move(e.touches[0].clientX, e.touches[0].clientY); }, { passive: true });
    window.addEventListener("touchend", up);

    let seaRafId = 0;
    let simT = 0;
    let introSimT0 = null;
    let lastSeaFrame = performance.now();
    let seaInViewport = true;

    function cancelSeaLoop() {
      if (seaRafId) cancelAnimationFrame(seaRafId);
      seaRafId = 0;
      lastSeaFrame = performance.now();
    }

    function startSeaLoopIfNeeded() {
      if (seaRafId) return;
      if (document.hidden || !seaInViewport) return;
      lastSeaFrame = performance.now();
      seaRafId = requestAnimationFrame(seaFrame);
    }

    function seaFrame(now) {
      seaRafId = 0;
      if (document.hidden || !seaInViewport) {
        lastSeaFrame = now;
        return;
      }
      const dt = Math.min(0.05, (now - lastSeaFrame) / 1000);
      lastSeaFrame = now;
      simT += dt;
      if (introSimT0 === null) introSimT0 = simT;
      const t = simT;
      const intro = Math.min(1, (simT - introSimT0) / 2);

      offX += (targX - offX) * 0.05;
      offY += (targY - offY) * 0.05;
      vx = offX - px;
      vy = offY - py;
      px = offX;
      py = offY;
      svx += (vx - svx) * 0.06;
      svy += (vy - svy) * 0.06;
      if (!drag) { svx *= 0.95; svy *= 0.95; }

      const dark = document.documentElement.classList.contains("dark") ? 1 : 0;
      gl.clearColor(dark ? 23 / 255 : 0, dark ? 23 / 255 : 0, dark ? 23 / 255 : 0, dark ? 1 : 0);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.uniform1f(uT, t);
      gl.uniform2f(uR, canvas.width, canvas.height * 1.92);
      gl.uniform2f(uOff, offX, offY);
      gl.uniform2f(uVel, svx * 60, svy * 60);
      if (uQ) gl.uniform1f(uQ, 1);
      if (uDark) gl.uniform1f(uDark, dark);
      if (uIntro) gl.uniform1f(uIntro, intro);
      gl.drawArrays(gl.TRIANGLES, 0, 3);

      seaRafId = requestAnimationFrame(seaFrame);
    }

    const seaIo = typeof IntersectionObserver !== "undefined"
      ? new IntersectionObserver(
        (entries) => {
          const e = entries[0];
          seaInViewport = !!(e && e.isIntersecting && e.intersectionRatio > 0);
          if (seaInViewport && !document.hidden) startSeaLoopIfNeeded();
          else cancelSeaLoop();
        },
        { root: null, threshold: 0, rootMargin: "0px" }
      )
      : null;
    if (seaIo) seaIo.observe(canvas);

    function onSeaVisibility() {
      if (document.hidden) cancelSeaLoop();
      else if (seaInViewport) startSeaLoopIfNeeded();
    }
    document.addEventListener("visibilitychange", onSeaVisibility, { passive: true });

    startSeaLoopIfNeeded();
  }

  function poll() {
    const parallelDone = !ext || gl.getProgramParameter(prog, ext.COMPLETION_STATUS_KHR);
    const timedOut = performance.now() > pollDeadline;
    if (parallelDone || timedOut) {
      if (timedOut && !parallelDone) console.warn("[sea] KHR_parallel_shader_compile still false; finalizing (possible iOS driver quirk)");
      finalize();
      return;
    }
    pollRaf = requestAnimationFrame(poll);
  }
  pollRaf = requestAnimationFrame(poll);
}

export const setupTocHashSync = (pushId) => () => { window.addEventListener("hashchange",()=>pushId(location.hash.slice(1)||"")); };