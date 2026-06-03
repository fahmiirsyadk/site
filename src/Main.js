/* global window, document, performance, requestAnimationFrame, cancelAnimationFrame, setTimeout, matchMedia, Math */
const SEA_FRAG_URL = "/assets/shaders/sea-footer.min.frag";

export const gfxBootCheckNoCubeHosts = () => {
  try {
    if (document.querySelectorAll("[data-cube-logo-host]").length === 0) {
      window.__gfxBoot?.markLogo();
    }
  } catch (_) {}
};
function scheduleHeavyGpuWork(fn) {
  let ran = false;
  const run = () => {
    if (ran) return;
    ran = true;
    fn();
  };
  requestAnimationFrame(() => run());
}

function seaDebugOn() {
  try {
    if (
      typeof sessionStorage !== "undefined" &&
      sessionStorage.getItem("sea-debug") === "1"
    )
      return true;
    return (
      typeof location !== "undefined" &&
      /(?:^|[?&])sea-debug=1(?:&|$)/.test(location.search)
    );
  } catch (_) {
    return false;
  }
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
    el.style.cssText =
      "position:fixed;left:0;right:0;bottom:0;max-height:42vh;overflow:auto;margin:0;padding:10px 12px;padding-bottom:max(12px,env(safe-area-inset-bottom,0px));font:11px/1.4 ui-monospace,monospace;background:#111827;color:#f3f4f6;border-top:3px solid #f59e0b;z-index:2147483646;white-space:pre-wrap;word-break:break-word;";
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
  if (r.fragmentLog)
    lines.push("--- fragment shader log ---", r.fragmentLog, "");
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
    patch,
  );
  renderSeaDebugHud();
}

function seaPerfMark(label) {
  const now = performance.now();
  if (typeof performance !== "undefined" && performance.mark) {
    try {
      performance.mark("sea:" + label);
    } catch (_) {}
  }
  window.__seaMountResult = Object.assign(window.__seaMountResult || {}, {
    ["ms_" + label]: now,
  });
}

/** Prefer default GPU on mobile; iOS can return null or flaky contexts with only `high-performance`. */
function getWebGL2ContextForSea(canvas) {
  const bases = [
    {
      alpha: true,
      premultipliedAlpha: false,
      antialias: false,
      powerPreference: "default",
    },
    {
      alpha: true,
      premultipliedAlpha: false,
      antialias: false,
      powerPreference: "high-performance",
    },
    {
      alpha: true,
      premultipliedAlpha: true,
      antialias: false,
      powerPreference: "default",
    },
    {
      alpha: true,
      premultipliedAlpha: true,
      antialias: true,
      powerPreference: "default",
    },
  ];
  for (let i = 0; i < bases.length; i++) {
    const gl = canvas.getContext("webgl2", bases[i]);
    if (gl) {
      setSeaMountResult({ contextAttrsIndex: i });
      if (seaDebugOn())
        console.log("[sea] WebGL2 context ok, attrs index", i, bases[i]);
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

/** --- SEA: start immediately, compile happens in parallel with boot animation --- */
let seaStarted = false;
function startSeaNow() {
  if (seaStarted) return;
  seaStarted = true;
  console.log("[sea] starting compile");
  window.__gfxBoot?.markPhase("sea_start", 3);
  scheduleHeavyGpuWork(runMountSeaFooter);
}
if (typeof window !== "undefined") {
  // Still listen for backwards compat if boot dispatches it, but we start
  // directly from mountSeaFooter now.
  window.addEventListener("gfx-boot-pause-for-sea", startSeaNow, {
    once: true,
  });
}
export const mountSeaFooter = () => {
  console.log("[sea] mountSeaFooter called");
  window.__gfxBoot?.markPhase("sea_mount", 1);
  startSeaNow();
};

function runMountSeaFooter() {
  console.log("[sea] runMountSeaFooter START");
  const canvas = document.getElementById("sea-canvas");
  if (!canvas) return;
  if (canvas.dataset.seaFooterInit === "1") return;
  canvas.dataset.seaFooterInit = "1";
  window.__gfxBoot?.markPhase("sea_fetch", 6);
  seaPerfMark("fetch_start");
  fetch(SEA_FRAG_URL)
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return r.text();
    })
    .then((t) => {
      seaPerfMark("fetch_end");
      window.__gfxBoot?.markPhase("sea_fetched", 18);
      initSeaFooterWithFragment(canvas, t.trim());
    })
    .catch((e) => {
      console.warn("[sea] fragment fetch failed", e);
      const em = e && e.message ? e.message : String(e);
      signalSeaReadyOnce(canvas, false, "fetch:" + em, { fetchError: em });
    });
}

const SEA_SIMPLE_FRAG =
  "#version 300 es\nprecision highp float;out vec4 o;uniform float t;uniform vec2 r;uniform vec2 cubeOff;uniform vec2 cubeVel;uniform float cloudQ;uniform float uiDark;uniform float seaIntro;mat3 rotX(float a){float s=sin(a),c=cos(a);return mat3(1,0,0,0,c,-s,0,s,c);}float wave(vec2 p,float tm){float w=0.;w+=sin(p.x*0.9+p.y*1.1-tm*1.7)*0.48;w+=sin(p.x*1.4-p.y*0.8+tm*1.2)*0.34;return w;}void main(){vec2 uv=(gl_FragCoord.xy-0.5*r)/r.y;float camT=smoothstep(0.0,1.0,clamp(seaIntro,0.0,1.0));vec3 ro=mix(vec3(0.0,2.5,-30.0),vec3(0.0,1.8,-7.5),camT);vec3 rd=normalize(vec3(uv,1.6));rd=rotX(0.05)*rd;float isSky=step(0.26,rd.y);float time=t*0.85;float D=uiDark;vec3 pageBg=vec3(0.090196);vec3 skyPaper=mix(vec3(1.0),pageBg,D);vec3 col=skyPaper;if(isSky<0.5){float th=-ro.y/rd.y;vec3 hit=ro+rd*((th>0.0)?th:1e-3);vec2 p=hit.xz;float wSea=wave(p*0.65,time);float seaSurf=wSea*0.78*0.25*2.7;float shorePulse=sin(p.x*0.8-time*0.9)*0.06;float shoreZ=0.80+seaSurf*0.95+shorePulse;float dist=p.y-shoreZ;float isSea=step(0.0,dist);float depthTint=clamp(dist*0.42,0.,3.);vec3 seaShallow=vec3(1.0,0.38,0.48);vec3 seaMid=vec3(0.97,0.22,0.33);vec3 seaDeep=vec3(0.82,0.11,0.19);vec3 sea=mix(seaShallow,seaMid,smoothstep(0.0,0.7,depthTint));sea=mix(sea,seaDeep,smoothstep(0.7,2.1,depthTint));vec3 sand=mix(vec3(1.0),pageBg*1.02,D);col=mix(sand,sea,isSea);float spec=pow(max(0.,dot(reflect(-normalize(vec3(0.3,0.8,0.4)),vec3(0.,1.,0.)),-rd)),32.0);col+=spec*0.15*vec3(1.0,0.92,0.88)*isSea;}col=clamp(col,0.0,1.0);float skyA=1.0-smoothstep(0.34,0.99,rd.y);float outASky=mix(1.0,skyA,isSky);float outA=mix(outASky,1.0,D);o=vec4(col,outA);}";

function initSeaFooterWithFragment(canvas, fullSrc) {
  if (!fullSrc) {
    signalSeaReadyOnce(canvas, false, "empty-fragment", { fragmentChars: 0 });
    return;
  }
  setSeaMountResult({ fragmentChars: fullSrc.length });
  if (seaDebugOn()) console.log("[sea] init fragment chars=" + fullSrc.length);

  const gl = getWebGL2ContextForSea(canvas);
  if (!gl) {
    console.warn(
      "[sea] no WebGL2 context (iOS needs 15+; check Settings → Safari → Advanced → Experimental features)",
    );
    signalSeaReadyOnce(canvas, false, "no-webgl2");
    return;
  }
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  const mqCoarse = matchMedia?.("(pointer: coarse)");
  const mqNarrow = matchMedia?.("(max-width: 768px)");
  const narrow = mqNarrow?.matches;
  const coarse = mqCoarse?.matches || narrow || navigator.maxTouchPoints > 0;
  const saveData = navigator.connection?.saveData;

  let canvasCssW = 1;
  let canvasCssH = 1;
  let lastDpr = 0;
  let lastW = 0;
  let lastH = 0;
  let resizeRaf = 0;
  const RESIZE_THRESHOLD_PX = 12;
  const applySize = () => {
    const r = canvas.getBoundingClientRect();
    const w = Math.max(1, r.width);
    const h = Math.max(1, r.height);
    const dpr = Math.min(
      devicePixelRatio || 1,
      saveData ? 1 : narrow ? 2 : coarse ? 1.28 : 2,
    );
    const dw = Math.abs(w - lastW);
    const dh = Math.abs(h - lastH);
    if (
      dw < RESIZE_THRESHOLD_PX &&
      dh < RESIZE_THRESHOLD_PX &&
      Math.abs(dpr - lastDpr) < 0.01
    )
      return;
    lastW = w;
    lastH = h;
    lastDpr = dpr;
    canvasCssW = w;
    canvasCssH = h;
    canvas.width = Math.max(1, Math.round(w * dpr));
    canvas.height = Math.max(1, Math.round(h * dpr));
    gl.viewport(0, 0, canvas.width, canvas.height);
  };
  applySize();
  const onResize = () => {
    if (resizeRaf) return;
    resizeRaf = requestAnimationFrame(() => {
      resizeRaf = 0;
      applySize();
    });
  };
  new ResizeObserver(onResize).observe(canvas);

  const vs =
    "#version 300 es\nvoid main(){vec2 v=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(v*2.-1.,0,1);}";
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
  function linkProgram(vsSrc, fsSrc, label) {
    const vsh = compileStage(gl.VERTEX_SHADER, vsSrc, label + "-vertex");
    const fsh = compileStage(gl.FRAGMENT_SHADER, fsSrc, label + "-fragment");
    if (!vsh || !fsh) return null;
    const p = gl.createProgram();
    gl.attachShader(p, vsh);
    gl.attachShader(p, fsh);
    gl.linkProgram(p);
    gl.deleteShader(vsh);
    gl.deleteShader(fsh);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
      console.warn("[sea] " + label + " link failed:", gl.getProgramInfoLog(p));
      gl.deleteProgram(p);
      return null;
    }
    return p;
  }

  window.__gfxBoot?.markPhase("sea_simple_compile", 20);
  // --- Simple shader: compile + link synchronously (fast) ---
  seaPerfMark("simple_link_start");
  const simpleProg = linkProgram(vs, SEA_SIMPLE_FRAG, "simple");
  seaPerfMark("simple_link_end");
  window.__gfxBoot?.markPhase("sea_simple_linked", 28);

  // Mutable render state; the loop reads from this object so we can swap programs live.
  const renderState = {
    prog: simpleProg,
    uT: null,
    uR: null,
    uOff: null,
    uVel: null,
    uQ: null,
    uDark: null,
    uIntro: null,
    isSimple: true,
  };

  function queryUniforms(prog) {
    gl.useProgram(prog);
    return {
      uT: gl.getUniformLocation(prog, "t"),
      uR: gl.getUniformLocation(prog, "r"),
      uOff: gl.getUniformLocation(prog, "cubeOff"),
      uVel: gl.getUniformLocation(prog, "cubeVel"),
      uQ: gl.getUniformLocation(prog, "cloudQ"),
      uDark: gl.getUniformLocation(prog, "uiDark"),
      uIntro: gl.getUniformLocation(prog, "seaIntro"),
    };
  }

  function applyUniforms(u, t, intro, dark) {
    gl.uniform1f(u.uT, t);
    gl.uniform2f(u.uR, canvas.width, canvas.height * 1.92);
    gl.uniform2f(u.uOff, offX, offY);
    gl.uniform2f(u.uVel, svx * 60, svy * 60);
    if (u.uDark) gl.uniform1f(u.uDark, dark);
    if (u.uIntro) gl.uniform1f(u.uIntro, intro);
  }

  let renderLoopStarted = false;
  let seaRafId = 0;
  let simT = 0;
  let introSimT0 = null;
  let introDone = false;
  let firstFrameMarked = false;
  let fullFirstFrameMarked = false;
  let lastSeaFrame = performance.now();
  let seaInViewport = true;
  let dark = document.documentElement.classList.contains("dark") ? 1 : 0;
  let lastClearDark = -1;
  let darkObserver = null;

  let offX = 0,
    offY = 0,
    targX = 0,
    targY = 0,
    vx = 0,
    vy = 0,
    svx = 0,
    svy = 0,
    px = 0,
    py = 0,
    drag = false,
    dsx = 0,
    dsy = 0,
    dbx = 0,
    dby = 0;
  const down = (x, y) => {
    drag = true;
    dsx = x;
    dsy = y;
    dbx = targX;
    dby = targY;
  };
  const move = (x, y) => {
    if (!drag) return;
    targX = Math.max(-7, Math.min(7, dbx + ((x - dsx) / canvasCssW) * 10));
    targY = Math.max(0, Math.min(11, dby - ((y - dsy) / canvasCssH) * 8));
  };
  const up = () => {
    drag = false;
  };
  canvas.addEventListener("mousedown", (e) => {
    down(e.clientX, e.clientY);
    e.preventDefault();
  });
  window.addEventListener("mousemove", (e) => move(e.clientX, e.clientY));
  window.addEventListener("mouseup", up);
  canvas.addEventListener(
    "touchstart",
    (e) => {
      const t = e.touches[0];
      down(t.clientX, t.clientY);
      e.preventDefault();
    },
    { passive: false },
  );
  window.addEventListener(
    "touchmove",
    (e) => {
      if (drag) move(e.touches[0].clientX, e.touches[0].clientY);
    },
    { passive: true },
  );
  window.addEventListener("touchend", up);

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
    let intro;
    if (introDone) {
      intro = 1.0;
    } else {
      intro = Math.min(1, (simT - introSimT0) / 2);
      if (intro >= 1.0) introDone = true;
    }

    offX += (targX - offX) * 0.05;
    offY += (targY - offY) * 0.05;
    vx = offX - px;
    vy = offY - py;
    px = offX;
    py = offY;
    svx += (vx - svx) * 0.06;
    svy += (vy - svy) * 0.06;
    if (!drag) {
      svx *= 0.95;
      svy *= 0.95;
    }

    if (dark !== lastClearDark) {
      lastClearDark = dark;
      gl.clearColor(
        dark ? 23 / 255 : 0,
        dark ? 23 / 255 : 0,
        dark ? 23 / 255 : 0,
        dark ? 1 : 0,
      );
    }
    if (!firstFrameMarked) {
      firstFrameMarked = true;
      seaPerfMark("first_frame");
      window.__gfxBoot?.markPhase("sea_first_frame", 38);
      const perf = window.__seaMountResult || {};
      console.log(
        "[sea] first frame (simple) | simpleLink=" +
          (perf.ms_simple_link_end - perf.ms_simple_link_start).toFixed(1) +
          "ms ready→1st=" +
          (perf.ms_first_frame - perf.ms_simple_link_end).toFixed(1) +
          "ms",
      );
    }
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(renderState.prog);
    applyUniforms(renderState, t, intro, dark);
    if (renderState.isSimple) {
      // simple shader ignores cloudQ, but set it anyway for consistency
      if (renderState.uQ) gl.uniform1f(renderState.uQ, 0);
    } else if (!fullFirstFrameMarked) {
      fullFirstFrameMarked = true;
      seaPerfMark("full_first_frame");
      console.log("[sea] FULL first frame → reporting 100%");
      window.__gfxBoot?.markPhase("sea_full_first_frame", 100);
      const perf2 = window.__seaMountResult || {};
      console.log(
        "[sea] first frame (full) | compile=" +
          (perf2.ms_compile_end - perf2.ms_compile_start).toFixed(1) +
          "ms link=" +
          (perf2.ms_link_end - perf2.ms_link_start).toFixed(1) +
          "ms total=" +
          (perf2.ms_full_first_frame - perf2.ms_fetch_start).toFixed(1) +
          "ms",
      );
    }
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    seaRafId = requestAnimationFrame(seaFrame);
  }

  const seaIo =
    typeof IntersectionObserver !== "undefined"
      ? new IntersectionObserver(
          (entries) => {
            const e = entries[0];
            seaInViewport = !!(
              e &&
              e.isIntersecting &&
              e.intersectionRatio > 0
            );
            if (seaInViewport && !document.hidden) startSeaLoopIfNeeded();
            else cancelSeaLoop();
          },
          { root: null, threshold: 0, rootMargin: "120px" },
        )
      : null;
  if (seaIo) seaIo.observe(canvas);

  function onSeaVisibility() {
    if (document.hidden) cancelSeaLoop();
    else if (seaInViewport) startSeaLoopIfNeeded();
  }
  document.addEventListener("visibilitychange", onSeaVisibility, {
    passive: true,
  });

  function startRenderLoop(prog, label) {
    if (!prog) return false;
    renderState.prog = prog;
    renderState.isSimple = label === "simple";
    Object.assign(renderState, queryUniforms(prog));
    if (renderState.uQ && label === "simple") gl.uniform1f(renderState.uQ, 0);
    const cloudQ = saveData ? 0.22 : narrow ? 0.45 : coarse ? 0.35 : 0.6;
    if (renderState.uQ && label !== "simple")
      gl.uniform1f(renderState.uQ, cloudQ);

    if (!renderLoopStarted) {
      renderLoopStarted = true;
      if (renderState.uDark && typeof MutationObserver !== "undefined") {
        darkObserver = new MutationObserver(() => {
          dark = document.documentElement.classList.contains("dark") ? 1 : 0;
        });
        darkObserver.observe(document.documentElement, {
          attributes: true,
          attributeFilter: ["class"],
        });
      }
      startSeaLoopIfNeeded();
    }
    return true;
  }

  // --- Activate simple shader immediately ---
  if (simpleProg) {
    window.__gfxBoot?.markPhase("sea_simple_active", 32);
    startRenderLoop(simpleProg, "simple");
    console.log("[sea] simple shader active");
    signalSeaReadyOnce(canvas, true, "", { programLog: "" });
  }

  // --- Full shader: compile + activate immediately (feeds boot progress to 100%) ---
  let fullDeferredOnce = false;

  function compileFullShaderNow() {
    if (fullDeferredOnce) return;
    fullDeferredOnce = true;

    window.__gfxBoot?.markPhase("sea_full_compile_start", 42);
    console.log("[sea] full shader compile START");
    seaPerfMark("compile_start");

    // --- Non-blocking parallel compile for the full fragment shader ---
    // Don't query COMPILE_STATUS immediately — that forces a synchronous
    // driver wait (1-3s on complex shaders). Instead use
    // KHR_parallel_shader_compile to poll completion, or fall back to
    // a short requestAnimationFrame yield before checking status.
    const extCompile = gl.getExtension("KHR_parallel_shader_compile");
    function compileShaderNonBlocking(type, source, label) {
      const sh = gl.createShader(type);
      gl.shaderSource(sh, source);
      gl.compileShader(sh);
      return sh;
    }

    const vshF = compileShaderNonBlocking(gl.VERTEX_SHADER, vs, "vertex");
    const fshF = compileShaderNonBlocking(
      gl.FRAGMENT_SHADER,
      fullSrc,
      "fragment",
    );

    let compilePollRaf = 0;
    let compilePollStart = performance.now();
    const compilePollDeadline = compilePollStart + 12000;

    function pollCompileCompletion() {
      if (compilePollRaf) cancelAnimationFrame(compilePollRaf);

      const vertDone =
        !extCompile ||
        gl.getShaderParameter(vshF, extCompile.COMPLETION_STATUS_KHR);
      const fragDone =
        !extCompile ||
        gl.getShaderParameter(fshF, extCompile.COMPLETION_STATUS_KHR);
      const timedOut = performance.now() > compilePollDeadline;

      // Report incremental progress during compile (44-68% range).
      if (vertDone && fragDone) {
        window.__gfxBoot?.markPhase("sea_full_compile_done", 68);
      } else {
        const elapsed = performance.now() - compilePollStart;
        const frac = Math.min(0.9, elapsed / 6000);
        window.__gfxBoot?.markPhase(
          "sea_full_compiling",
          44 + Math.round(frac * 24),
        );
      }

      if (vertDone && fragDone) {
        // Both shaders compiled — now check status.
        seaPerfMark("compile_end");
        const vertOk = gl.getShaderParameter(vshF, gl.COMPILE_STATUS);
        const fragOk = gl.getShaderParameter(fshF, gl.COMPILE_STATUS);
        if (!vertOk)
          seaDiag.vertexLog = gl.getShaderInfoLog(vshF) || "(no log)";
        if (!fragOk)
          seaDiag.fragmentLog = gl.getShaderInfoLog(fshF) || "(no log)";
        if (!vertOk || !fragOk) {
          console.error("[sea] full shader compile failed");
          if (!vertOk) gl.deleteShader(vshF);
          if (!fragOk) gl.deleteShader(fshF);
          signalSeaReadyOnce(canvas, false, "shader-compile", {
            vertexLog: seaDiag.vertexLog,
            fragmentLog: seaDiag.fragmentLog,
          });
          return;
        }
        linkFullProgram(vshF, fshF);
        return;
      }

      if (timedOut) {
        console.warn("[sea] compile poll timed out; checking regardless");
        seaPerfMark("compile_end");
        const vertOk = gl.getShaderParameter(vshF, gl.COMPILE_STATUS);
        const fragOk = gl.getShaderParameter(fshF, gl.COMPILE_STATUS);
        if (!vertOk)
          seaDiag.vertexLog = gl.getShaderInfoLog(vshF) || "(no log)";
        if (!fragOk)
          seaDiag.fragmentLog = gl.getShaderInfoLog(fshF) || "(no log)";
        if (!vertOk || !fragOk) {
          if (!vertOk) gl.deleteShader(vshF);
          if (!fragOk) gl.deleteShader(fshF);
          signalSeaReadyOnce(canvas, false, "shader-compile", {
            vertexLog: seaDiag.vertexLog,
            fragmentLog: seaDiag.fragmentLog,
          });
          return;
        }
        linkFullProgram(vshF, fshF);
        return;
      }

      compilePollRaf = requestAnimationFrame(pollCompileCompletion);
    }

    // Yield to the browser before starting the poll so the current frame can paint.
    compilePollRaf = requestAnimationFrame(pollCompileCompletion);

    function linkFullProgram(vsh, fsh) {
      window.__gfxBoot?.markPhase("sea_full_link_start", 72);
      seaPerfMark("link_start");
      const fullProg = gl.createProgram();
      gl.attachShader(fullProg, vsh);
      gl.attachShader(fullProg, fsh);
      gl.linkProgram(fullProg);
      gl.deleteShader(vsh);
      gl.deleteShader(fsh);

      let fullFinished = false;
      const ext2 = gl.getExtension("KHR_parallel_shader_compile");
      const pollDeadline = performance.now() + 14000;
      let pollRaf = 0;
      let linkPollStart = performance.now();
      let noExtLastCheck = 0;

      function finalizeFull() {
        if (fullFinished) return;
        fullFinished = true;
        if (pollRaf) cancelAnimationFrame(pollRaf);

        // Activate full shader immediately so first frame can reach 100%.
        window.__gfxBoot?.markPhase("sea_full_active", 92);
        startRenderLoop(fullProg, "full");

        // If the sea canvas is off-screen when the full shader activates (e.g. an
        // article page where the footer is far below the fold), seaFrame skips its
        // body early and fullFirstFrameMarked never gets set. Schedule a fallback rAF
        // so the boot overlay can complete without waiting for the 15-second hard timeout.
        requestAnimationFrame(function () {
          if (!fullFirstFrameMarked) {
            fullFirstFrameMarked = true;
            seaPerfMark("full_first_frame");
            console.log("[sea] FULL first frame → reporting 100%");
            window.__gfxBoot?.markPhase("sea_full_first_frame", 100);
            const perf2 = window.__seaMountResult || {};
            console.log(
              "[sea] first frame (full) | compile=" +
                (perf2.ms_compile_end - perf2.ms_compile_start).toFixed(1) +
                "ms link=" +
                (perf2.ms_link_end - perf2.ms_link_start).toFixed(1) +
                "ms total=" +
                (perf2.ms_full_first_frame - perf2.ms_fetch_start).toFixed(1) +
                "ms",
            );
          }
        });

        const cloudQ = saveData ? 0.22 : narrow ? 0.45 : coarse ? 0.35 : 0.6;
        const perf = window.__seaMountResult || {};
        console.log(
          "[sea] full shader active; cloudQ=" +
            cloudQ +
            " | fetch=" +
            (perf.ms_fetch_end - perf.ms_fetch_start).toFixed(1) +
            "ms compile=" +
            (perf.ms_compile_end - perf.ms_compile_start).toFixed(1) +
            "ms link=" +
            (perf.ms_link_end - perf.ms_link_start).toFixed(1) +
            "ms simpleLink=" +
            (perf.ms_simple_link_end - perf.ms_simple_link_start).toFixed(1) +
            "ms",
        );
      }

      function pollFull() {
        const hasExt = !!ext2;
        const timedOut = performance.now() > pollDeadline;
        const elapsed = performance.now() - linkPollStart;
        const frac = Math.min(0.9, elapsed / 5000);
        const pct = 76 + Math.round(frac * 12);

        // Always report incremental progress (76→88% over ~5s).
        if (Math.round(frac * 50) % 10 === 0) {
          console.log(
            "[sea] link polling: " +
              elapsed.toFixed(0) +
              "ms  → progress=" +
              pct +
              "%",
          );
        }
        window.__gfxBoot?.markPhase("sea_full_linking", pct);

        if (hasExt) {
          // Non-blocking poll via KHR_parallel_shader_compile
          const parallelDone = gl.getProgramParameter(
            fullProg,
            ext2.COMPLETION_STATUS_KHR,
          );
          if (parallelDone || timedOut) {
            if (timedOut && !parallelDone)
              console.warn(
                "[sea] KHR_parallel_shader_compile still false; finalizing",
              );
            // Yield before checking LINK_STATUS so progress bar can paint
            requestAnimationFrame(function () {
              seaPerfMark("link_end");
              window.__gfxBoot?.markPhase("sea_full_linked", 88);
              if (!gl.getProgramParameter(fullProg, gl.LINK_STATUS)) {
                const log = gl.getProgramInfoLog(fullProg) || "(no log)";
                console.error("[sea] full program link failed:\n" + log);
                return;
              }
              finalizeFull();
            });
            return;
          }
        } else {
          // No KHR extension: let progress updates paint before checking
          // LINK_STATUS, which may block on some drivers.
          var shouldCheck =
            timedOut ||
            (elapsed > 1000 &&
              elapsed - noExtLastCheck > 500 &&
              noExtLastCheck > 0);
          if (!noExtLastCheck) shouldCheck = elapsed > 1800;
          if (shouldCheck) {
            noExtLastCheck = elapsed;
            // Yield before the potential block so progress bar paints
            requestAnimationFrame(function () {
              seaPerfMark("link_end");
              window.__gfxBoot?.markPhase("sea_full_linked", 88);
              const ok = gl.getProgramParameter(fullProg, gl.LINK_STATUS);
              if (ok || timedOut) {
                if (!ok) {
                  console.warn(
                    "[sea] link status timeout; activating anyway",
                  );
                }
                finalizeFull();
                return;
              }
              pollRaf = requestAnimationFrame(pollFull);
            });
            return;
          }
        }

        pollRaf = requestAnimationFrame(pollFull);
      }
      pollRaf = requestAnimationFrame(pollFull);
    }
  }

  // Start full shader compilation after a short delay so the simple shader
  // has a few frames to settle and the boot animation is already visible.
  window.__gfxBoot?.markPhase("sea_full_scheduling", 39);
  setTimeout(() => {
    window.__gfxBoot?.markPhase("sea_full_scheduled", 41);
    if (!fullDeferredOnce) compileFullShaderNow();
  }, 200);
}

export const setupTocHashSync = (pushId) => () => {
  window.addEventListener("hashchange", () =>
    pushId(location.hash.slice(1) || ""),
  );
};
