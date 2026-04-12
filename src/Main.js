/** Sea fragment: `pnpm run shaders` writes public/assets/shaders/sea-footer.min.frag */
const SEA_FRAG_URL = "/assets/shaders/sea-footer.min.frag";

export const everyMsInterval = (ms) => (eff) => () => {
  setInterval(() => eff(), ms);
};

export const afterPaint = (eff) => () => {
  requestAnimationFrame(() => eff());
};

export const fetchText = (url) => (onOk) => (onErr) => () => {
  fetch(url)
  .then((resp) => {
      if (!resp.ok) throw new Error(`HTTP ${resp.status} for ${url}`);
      return resp.text();
    })
  .then((text) => onOk(text)())
  .catch((err) => onErr(String(err))());
};

const THEME_STORAGE_KEY = "theme";

const prefersDark = () => {
  try {
    return typeof matchMedia !== "undefined" && matchMedia("(prefers-color-scheme: dark)").matches;
  } catch (_) {
    return false;
  }
};

const getStoredMode = () => {
  try {
    const s = localStorage.getItem(THEME_STORAGE_KEY);
    if (s === "light" || s === "dark" || s === "system") return s;
  } catch (_) {}
  return "system";
};

const effectiveDark = (mode) => mode === "dark" || (mode === "system" && prefersDark());

/** Must match collapsed `.tool-display-body` max-height in css/style.css */
const TOOL_DISPLAY_COLLAPSED_MAX_PX = 200;

/** One-shot measure for tool/diff cards; Luna islands get `ToolCardMeasured` via `cb`. String HTML cards sync classes in DOM only. */
export const measureToolCards = (cb) => () => {
  document
    .querySelectorAll('[data-component="tool-display-card"][data-block-id]:not(.terminal-card)')
    .forEach((card) => {
      const id = card.dataset.blockId;
      const body = card.querySelector(".tool-display-body");
      if (!id || !body) return;
      const prev = body.style.maxHeight;
      body.style.maxHeight = "none";
      const h = body.scrollHeight;
      body.style.maxHeight = prev;
      cb(id)(h)();
      const lunaIsland = card.getAttribute("data-measured-island") === "true";
      if (!lunaIsland) {
        const btn = card.querySelector(".tool-display-expand-btn");
        if (h <= TOOL_DISPLAY_COLLAPSED_MAX_PX + 1) {
          card.classList.add("tool-display-card--no-expand");
          card.classList.remove("is-expanded");
          if (btn) btn.setAttribute("aria-expanded", "false");
        } else {
          card.classList.remove("tool-display-card--no-expand");
          card.classList.add("is-expanded");
          if (btn) btn.setAttribute("aria-expanded", "true");
        }
      }
    });
};

let markdownProseDelegationBound = false;

/** Delegated handlers for markdown HTML inside `unsafeRawHtml` (no inline `onclick`). */
export const initMarkdownProseDelegation = (appNode) => () => {
  if (!appNode || markdownProseDelegationBound) return;
  markdownProseDelegationBound = true;

  appNode.addEventListener("click", (e) => {
    const toolBtn = e.target.closest("[data-tool-display-toggle]");
    if (toolBtn && appNode.contains(toolBtn)) {
      const card = toolBtn.closest('[data-component="tool-display-card"]');
      if (card && !card.classList.contains("terminal-card")) {
        const was = toolBtn.getAttribute("aria-expanded") === "true";
        const next = !was;
        toolBtn.setAttribute("aria-expanded", String(next));
        card.classList.toggle("is-expanded", next);
        e.preventDefault();
        return;
      }
    }
    /* String-built terminals only (see `BodyBlockHtml.renderTerminalShell`). Luna `TerminalCard` has no `data-terminal-toggle`. */
    const tToggle = e.target.closest("[data-terminal-toggle]");
    if (tToggle && appNode.contains(tToggle)) {
      const id = tToggle.dataset.target;
      if (!id) return;
      const body = document.getElementById(id);
      const wasExpanded = tToggle.getAttribute("aria-expanded") === "true";
      tToggle.setAttribute("aria-expanded", String(!wasExpanded));
      if (body) body.hidden = wasExpanded;
      e.preventDefault();
      return;
    }
    const tCopy = e.target.closest("[data-terminal-copy]");
    if (tCopy && appNode.contains(tCopy)) {
      const cmd = tCopy.dataset.command || "";
      if (navigator.clipboard?.writeText) {
        navigator.clipboard.writeText(cmd).catch(() => {});
      }
      tCopy.setAttribute("title", "Copied");
      tCopy.dataset.copied = "1";
      setTimeout(() => {
        delete tCopy.dataset.copied;
        tCopy.setAttribute("title", "Copy");
      }, 900);
      e.preventDefault();
    }
  });
};

export const getStoredThemeMode = () => getStoredMode();

export const applyThemeMode = (mode) => () => {
  try {
    localStorage.setItem(THEME_STORAGE_KEY, mode);
  } catch (_) {}
  const dark = effectiveDark(mode);
  const root = document.documentElement;
  root.classList.toggle("dark", dark);
  try {
    root.style.colorScheme = dark ? "dark" : "light";
  } catch (_) {}
};

export const subscribeSystemThemeChanges = (cb) => () => {
  const mq = typeof matchMedia !== "undefined" ? matchMedia("(prefers-color-scheme: dark)") : null;
  const run = () => cb()();
  if (mq && mq.addEventListener) mq.addEventListener("change", run);
  else if (mq && mq.addListener) mq.addListener(run);
};

/** Align theme `aria-pressed` with storage before Luna hydrate (SSR uses no selection). */
export const patchSsrThemeButtons = (mode) => () => {
  const labelToMode = new Map([
    ["Use light theme", "light"],
    ["Use dark theme", "dark"],
    ["Use device theme", "system"],
  ]);
  document.querySelectorAll("[data-theme-controls] button[aria-label]").forEach((btn) => {
    const m = labelToMode.get(btn.getAttribute("aria-label"));
    if (m) btn.setAttribute("aria-pressed", m === mode ? "true" : "false");
  });
};

const scheduleHeavyGpuWork = (fn) => {
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(() => fn(), { timeout: 2800 });
  } else {
    requestAnimationFrame(() => setTimeout(fn, 0));
  }
};

export const mountSeaFooter = () => {
  const canvas = document.getElementById("sea-canvas");
  if (!canvas) return;
  fetch(SEA_FRAG_URL)
    .then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status} for ${SEA_FRAG_URL}`);
      return r.text();
    })
    .then((rawFrag) => {
      const seaFooterFragmentSource = rawFrag.trim();
      if (!seaFooterFragmentSource.startsWith("#version")) {
        throw new Error("sea fragment missing #version");
      }
      scheduleHeavyGpuWork(() => initSeaFooterWithFragment(canvas, seaFooterFragmentSource));
    })
    .catch((err) => {
      console.warn("[sea-footer]", err);
    });
};

function initSeaFooterWithFragment(canvas, seaFooterFragmentSource) {
  const mqCoarse = typeof matchMedia !== "undefined" && matchMedia("(pointer: coarse)");
  const mqNarrow = typeof matchMedia !== "undefined" && matchMedia("(max-width: 768px)");
  const narrowUi = mqNarrow && mqNarrow.matches;
  const coarseUi =
    (mqCoarse && mqCoarse.matches) ||
    narrowUi ||
    (typeof navigator !== "undefined" && navigator.maxTouchPoints > 0);
  const saveData = typeof navigator !== "undefined" && navigator.connection && navigator.connection.saveData;
  const cloudRampSec = 1.15 + Math.random() * 1.85;
  const cloudStartFrac = 0.2 + Math.random() * 0.22;
  const mountWallStart = performance.now();
  const useTextureNoise = coarseUi || saveData;
  const dprNative = typeof devicePixelRatio === "number" && devicePixelRatio > 0 ? devicePixelRatio : 1;
  const dprMax = saveData ? 1 : narrowUi ? Math.min(2, dprNative) : coarseUi ? 1.28 : 2;
  const dprNow = () => Math.min(dprNative, dprMax);
  const gpuEveryNthFrame = narrowUi ? 1 : coarseUi && !saveData ? 2 : 1;
  let gpuFrame = 0;
  const ctxBase = {
    alpha: true,
    premultipliedAlpha: false,
    antialias: false,
    powerPreference: "high-performance",
  };
  let gl = canvas.getContext("webgl2", { ...ctxBase, colorSpace: "srgb", desynchronized: true });
  if (!gl) gl = canvas.getContext("webgl2", { ...ctxBase, desynchronized: true });
  if (!gl) gl = canvas.getContext("webgl2", ctxBase);
  if (!gl) return;
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.enable(gl.SCISSOR_TEST);
  gl.clearColor(0, 0, 0, 0);

  /** Set `true` to magenta-clear the full buffer and verify GL covers the bitmap (see applySize `ceil` note). */
  const SEA_DEBUG_FULL_CLEAR_COLOR = false;

  /**
   * Drawing only the bottom X% of the buffer (smaller viewport) remaps the fullscreen tri → `uv`/`rd`
   * don’t match the shader’s assumptions → bad hits, transparent sky alpha, pale “gaps” at the bottom.
   * One full pass per frame; keep cost down with short CSS height + cloudQ ramp instead.
   */
  /** Higher → narrower rays / “closer” camera on short canvases (try 1.6–2.2). */
  const SEA_UV_RY_MULT = 1.92;
  const seaDrawH = () => canvas.height;
  const seaUvR = () => canvas.height * SEA_UV_RY_MULT;

  const syncClearColor = () => {
    if (document.documentElement.classList.contains("dark")) gl.clearColor(23 / 255, 23 / 255, 23 / 255, 1);
    else gl.clearColor(0, 0, 0, 0);
  };
  /** Scissored clear only touches the bottom band — the top of the bitmap stays uncleared (white). Clear the full buffer, then scissor for draws only. */
  const clearFullFramebuffer = () => {
    if (SEA_DEBUG_FULL_CLEAR_COLOR) gl.clearColor(1, 0, 0.85, 1);
    else syncClearColor();
    gl.disable(gl.SCISSOR_TEST);
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.enable(gl.SCISSOR_TEST);
  };
  const seaViewportScissor = () => {
    const h = seaDrawH();
    gl.viewport(0, 0, canvas.width, h);
    gl.scissor(0, 0, canvas.width, h);
  };

  const applySize = () => {
    const rect = canvas.getBoundingClientRect();
    const dpr = dprNow();
    /* Ceil avoids a 1px tall “white hairline” at the top: round() can undersize the bitmap vs CSS box × DPR. */
    const w = Math.max(1, Math.ceil(rect.width * dpr));
    const hFull = Math.max(1, Math.ceil(rect.height * dpr));
    if (canvas.width !== w || canvas.height !== hFull) {
      canvas.width = w;
      canvas.height = hFull;
    }
    clearFullFramebuffer();
    seaViewportScissor();
  };
  let resizeScheduled = false;
  const resize = () => {
    if (resizeScheduled) return;
    resizeScheduled = true;
    requestAnimationFrame(() => {
      resizeScheduled = false;
      applySize();
    });
  };
  applySize();
  new ResizeObserver(resize).observe(canvas);

  const vs = `#version 300 es
void main(){vec2 v=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(v*2.-1.,0,1);}`;

  const mkSh=(t,s)=>{const sh=gl.createShader(t);gl.shaderSource(sh,s);gl.compileShader(sh);return sh;};
  const fsSource=useTextureNoise
    ?seaFooterFragmentSource.replace(/^#version\s+[^\n]+\n/,"$&#define USE_TEXTURE_NOISE\n")
    :seaFooterFragmentSource;
  const vsh=mkSh(gl.VERTEX_SHADER,vs),fsh=mkSh(gl.FRAGMENT_SHADER,fsSource);
  const prog=gl.createProgram();
  gl.attachShader(prog,vsh);gl.attachShader(prog,fsh);gl.linkProgram(prog);
  // Do not call getProgramParameter(LINK_STATUS) here. With KHR_parallel_shader_compile,
  // linkProgram may still be in flight; reading LINK_STATUS forces a sync wait (~hundreds of ms
  // in DevTools at this line). finalizeProg + pollShader below handle completion.
  let shaderReady=false,uT,uR,uCubeOff,uCubeVel,uCloudQ,uUiDark,uNoiseLoc=null;
  const parallelExt=gl.getExtension('KHR_parallel_shader_compile');
  const finalizeProg=()=>{
    if(!gl.getShaderParameter(vsh,gl.COMPILE_STATUS)){console.error("[sea-canvas] vertex compile:",gl.getShaderInfoLog(vsh));return;}
    if(!gl.getShaderParameter(fsh,gl.COMPILE_STATUS)){console.error("[sea-canvas] fragment compile:",gl.getShaderInfoLog(fsh));return;}
    if(!gl.getProgramParameter(prog,gl.LINK_STATUS)){console.error("[sea-canvas] program link:",gl.getProgramInfoLog(prog));return;}
    gl.useProgram(prog);
    uT=gl.getUniformLocation(prog,"t");uR=gl.getUniformLocation(prog,"r");uCubeOff=gl.getUniformLocation(prog,"cubeOff");uCubeVel=gl.getUniformLocation(prog,"cubeVel");uCloudQ=gl.getUniformLocation(prog,"cloudQ");uUiDark=gl.getUniformLocation(prog,"uiDark");
    uNoiseLoc=null;
    if(useTextureNoise){
      uNoiseLoc=gl.getUniformLocation(prog,"uNoise");
      const noiseTex=gl.createTexture();
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D,noiseTex);
      const size=256,data=new Uint8Array(size*size);
      for(let i=0;i<data.length;i++)data[i]=Math.random()*255|0;
      gl.texImage2D(gl.TEXTURE_2D,0,gl.R8,size,size,0,gl.RED,gl.UNSIGNED_BYTE,data);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.REPEAT);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.REPEAT);
    }
    shaderReady=true;
  };
  const pollShader=()=>{
    if(!parallelExt||gl.getProgramParameter(prog,parallelExt.COMPLETION_STATUS_KHR))finalizeProg();
    else requestAnimationFrame(pollShader);
  };
  requestAnimationFrame(pollShader);
  let cubeOffX=0,cubeOffY=0,cubeTargX=0,cubeTargY=0,velX=0,velY=0,smoothVelX=0,smoothVelY=0,prevOffX=0,prevOffY=0,dragging=false,dragStartX=0,dragStartY=0,dragBaseX=0,dragBaseY=0;
  const DRAG_SCALE_X=10,DRAG_SCALE_Y=8,CLAMP_X=7,CLAMP_Y_MIN=0,CLAMP_Y_MAX=11,EASE=0.05,VEL_SMOOTH=0.06,VEL_DECAY=0.95;
  const pointerDown=(px,py)=>{dragging=true;dragStartX=px;dragStartY=py;dragBaseX=cubeTargX;dragBaseY=cubeTargY;};
  const pointerMove=(px,py)=>{if(!dragging)return;const rect=canvas.getBoundingClientRect();const dx=(px-dragStartX)/rect.width;const dy=(py-dragStartY)/rect.height;cubeTargX=Math.max(-CLAMP_X,Math.min(CLAMP_X,dragBaseX+dx*DRAG_SCALE_X));cubeTargY=Math.max(CLAMP_Y_MIN,Math.min(CLAMP_Y_MAX,dragBaseY-dy*DRAG_SCALE_Y));};
  const pointerUp=()=>{dragging=false;};
  canvas.addEventListener("mousedown",e=>{pointerDown(e.clientX,e.clientY);e.preventDefault();}); window.addEventListener("mousemove",e=>pointerMove(e.clientX,e.clientY)); window.addEventListener("mouseup",pointerUp);
  canvas.addEventListener("touchstart",e=>{const t=e.touches[0];pointerDown(t.clientX,t.clientY);e.preventDefault();},{passive:false}); window.addEventListener("touchmove",e=>{if(!dragging)return;const t=e.touches[0];pointerMove(t.clientX,t.clientY);},{passive:true});   window.addEventListener("touchend",pointerUp); window.addEventListener("touchcancel",pointerUp);
  let rafStart=null,animT=0,savedAnimT=0,rafId=null,footerVisible=false;
  let reduceMotion=typeof matchMedia!=="undefined"&&matchMedia("(prefers-reduced-motion: reduce)").matches;
  const mqRm=typeof matchMedia!=="undefined"?matchMedia("(prefers-reduced-motion: reduce)"):null;
  const onReduceMotion=()=>{
    const was=reduceMotion;reduceMotion=mqRm.matches;
    if(!was&&reduceMotion)savedAnimT=animT;
    if(was&&!reduceMotion&&rafStart!==null)rafStart=performance.now()-savedAnimT*1000;
  };
  if(mqRm&&mqRm.addEventListener)mqRm.addEventListener("change",onReduceMotion);else if(mqRm&&mqRm.addListener)mqRm.addListener(onReduceMotion);
  const drawFrame=(ts,drawGpu)=>{
    if(rafStart===null)rafStart=ts;
    if(!reduceMotion){animT=(ts-rafStart)/1000;savedAnimT=animT;}else{animT=savedAnimT;}
    cubeOffX+=(cubeTargX-cubeOffX)*EASE;cubeOffY+=(cubeTargY-cubeOffY)*EASE;velX=cubeOffX-prevOffX;velY=cubeOffY-prevOffY;prevOffX=cubeOffX;prevOffY=cubeOffY;smoothVelX+=(velX-smoothVelX)*VEL_SMOOTH;smoothVelY+=(velY-smoothVelY)*VEL_SMOOTH;if(!dragging){smoothVelX*=VEL_DECAY;smoothVelY*=VEL_DECAY;}
    if(drawGpu!==false&&shaderReady){
      const cloudQMax=reduceMotion?0.22:saveData?0.26:narrowUi?0.34:coarseUi?0.34:1.0;
      let cloudQ=cloudQMax;
      if(!reduceMotion){
        const elapsed=(performance.now()-mountWallStart)/1000;
        const u=Math.min(1,elapsed/cloudRampSec);
        const ease=u*u*(3-2*u);
        cloudQ=cloudQMax*(cloudStartFrac+(1-cloudStartFrac)*ease);
      }
      const uiDark=document.documentElement.classList.contains("dark")?1.0:0.0;
      clearFullFramebuffer();
      seaViewportScissor();
      gl.uniform1f(uT,animT);gl.uniform2f(uR,canvas.width,seaUvR());gl.uniform2f(uCubeOff,cubeOffX,cubeOffY);gl.uniform2f(uCubeVel,smoothVelX*60,smoothVelY*60);if(uCloudQ)gl.uniform1f(uCloudQ,cloudQ);if(uUiDark)gl.uniform1f(uUiDark,uiDark);if(useTextureNoise&&uNoiseLoc){gl.activeTexture(gl.TEXTURE0);gl.uniform1i(uNoiseLoc,0);}gl.drawArrays(gl.TRIANGLES,0,3);
    }
  };
  const frame=(ts)=>{
    gpuFrame+=1;
    const drawGpu=gpuEveryNthFrame<=1||(gpuFrame%gpuEveryNthFrame===0)||dragging;
    drawFrame(ts,drawGpu);
    rafId=requestAnimationFrame(frame);
  };
  const stopAnim=()=>{if(rafId){cancelAnimationFrame(rafId);rafId=null;}savedAnimT=animT;};
  const syncLoop=()=>{
    const run=footerVisible&&document.visibilityState==="visible";
    if(run&&!rafId)rafId=requestAnimationFrame(frame);
    if(!run&&rafId)stopAnim();
  };
  const resumeAnim=()=>{rafStart=performance.now()-savedAnimT*1000;syncLoop();};
  document.addEventListener("visibilitychange",()=>{
    if(document.visibilityState==="hidden")stopAnim();
    else if(footerVisible)resumeAnim();
  });
  const io=new IntersectionObserver(es=>{
    footerVisible=es[0].isIntersecting;
    if(footerVisible)resumeAnim();else stopAnim();
  },{threshold:0.01});
  io.observe(canvas);
  clearFullFramebuffer();
  seaViewportScissor();
}

/** Sync TOC highlight from the URL hash (full load + in-page # changes). Used on mobile instead of scroll-spy. */
export const setupTocHashSync = (pushId) => () => {
  window.addEventListener(
    "hashchange",
    function () {
      var h = location.hash || "";
      pushId(h.length > 1 ? h.slice(1) : "")();
    },
    false,
  );
};
