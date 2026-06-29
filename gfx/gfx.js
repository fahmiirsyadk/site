/* gfx.js -- single-file WebGL boot scene + cube logo + sea canvas.
   Vanilla JS, no framework, no bundler. WebGL 2 required (graceful skip otherwise).
   Loaded async; self-initializes on DOMContentLoaded.
   Optimized vs. reference (PureScript): no SPA runtime, no hydration, no model
   serialization, single ~13KB file, IntersectionObserver lazy-mount, pause off-screen. */
(function () {
  "use strict";

  // ======================================================================
  // 0. Feature detect
  // ======================================================================

  var probe = document.createElement("canvas");
  var WEBGL2 = !!(probe.getContext && probe.getContext("webgl2"));
  var WEBGL = WEBGL2 || !!(probe.getContext && (probe.getContext("webgl") || probe.getContext("experimental-webgl")));

  var rm = window.matchMedia ? window.matchMedia("(prefers-reduced-motion: reduce)") : { matches: false };
  var reduceMotion = rm.matches;
  if (rm.addEventListener) rm.addEventListener("change", function (e) { reduceMotion = e.matches; });

  // ======================================================================
  // 1. Boot coordinator (window.__gfxBoot)
  // ======================================================================

  var boot = (window.__gfxBoot = {
    sea: false,
    logo: false,
    dismissed: false,
    animationDone: false,
    _progressPhases: {},
    _targetProgress: 0,
    setProgress: function (phase, pct) {
      if (boot.dismissed || boot.animationDone) return;
      boot._progressPhases[phase] = pct;
      var max = 0;
      for (var k in boot._progressPhases) if (boot._progressPhases[k] > max) max = boot._progressPhases[k];
      boot._targetProgress = Math.max(0, Math.min(100, max));
    },
    markPhase: function (p, v) { boot.setProgress(p, v); },
    markLogo: function () {
      if (boot.logo || boot.dismissed) return;
      boot.logo = true;
      boot._try();
    },
    markSea: function () {
      if (boot.sea || boot.dismissed) return;
      boot.sea = true;
      boot._try();
    },
    _try: function () {
      if (boot.dismissed || !boot.logo || !boot.sea || !boot.animationDone) return;
      boot.dismissed = true;
      var el = document.getElementById("gfx-boot-overlay");
      if (el) { el.setAttribute("data-state", "done"); try { el.remove(); } catch (_) {} }
    },
  });
  setTimeout(function () { if (!boot.dismissed && !boot.sea) boot.markSea(); }, 12000);
  setTimeout(function () { if (!boot.dismissed && !boot.logo) boot.markLogo(); }, 12000);

  // ======================================================================
  // 2. Boot overlay: canvas 2D, red fill + destination-out holes
  // ======================================================================

  var bootAnim = null;
  function startBootAnim() {
    if (bootAnim) return;
    var overlay = document.getElementById("gfx-boot-overlay");
    var canvas = document.getElementById("gfx-boot-canvas");
    var counterEl = document.getElementById("gfx-boot-counter");
    var progressEl = document.getElementById("gfx-boot-progress");
    if (!overlay || !canvas || !counterEl) return;
    var ctx = canvas.getContext("2d", { alpha: true });
    if (!ctx) return;
    canvas.style.backgroundColor = "transparent";

    var dpr = 1, W = 0, H = 0, CELL = 56, cols = 0, rows = 0, total = 0;
    var indices = [], filled = [], spawned = 0, ptr = 0, rafId = 0, chromeRemoved = false;
    var lastCounter = -1, lastProgress = -1;
    var isHidden = document.hidden, activeElapsed = 0, lastActive = performance.now(), bootStartTime = lastActive;
    var displayedProgress = 0, gridDisplayed = 0, progressFromMilestones = 0;
    var lastMilestoneChange = 0, lastMilestoneValue = 0;

    function getActiveTime(now) { return activeElapsed + (isHidden ? 0 : now - lastActive); }
    function onVisibility() {
      var now = performance.now();
      if (document.hidden) {
        if (!isHidden) { activeElapsed += now - lastActive; isHidden = true; }
        if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
      } else {
        isHidden = false; lastActive = now;
        if (!rafId) rafId = requestAnimationFrame(tick);
      }
    }
    document.addEventListener("visibilitychange", onVisibility, { passive: true });

    function buildOrder() {
      indices.length = 0;
      var cx = (cols - 1) / 2, cy = (rows - 1) / 2, ring = 0.85;
      for (var r = 0; r < rows; r++) for (var c = 0; c < cols; c++) {
        var dx = c - cx, dy = r - cy, dist2 = dx*dx + dy*dy, rad = Math.sqrt(dist2), ang = Math.atan2(dy, dx);
        indices.push({ id: r*cols + c, dist2: dist2, swirl: ang + rad*ring });
      }
      indices.sort(function (a, b) { if (a.dist2 !== b.dist2) return a.dist2 - b.dist2; return a.swirl - b.swirl; });
    }

    // Render sizing only: canvas backing store + transform. Never touches the
    // grid model (cols/rows/total/indices), so it is always safe to call alone.
    function resizeCanvas() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      var br = overlay.getBoundingClientRect();
      W = Math.max(1, Math.round(br.width)); H = Math.max(1, Math.round(br.height));
      canvas.width = Math.max(1, Math.floor(W * dpr));
      canvas.height = Math.max(1, Math.floor(H * dpr));
      canvas.style.width = W + "px"; canvas.style.height = H + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = false;
    }

    // Grid model: cols/rows/total and the spawn order are the single source of
    // truth and are always rewritten together, so `total` and `indices.length`
    // can never diverge. (buildOrder() fills `indices` with exactly `total` cells.)
    function rebuildGrid() {
      CELL = W < 640 ? 44 : 56;
      cols = Math.ceil(W / CELL) + 2; rows = Math.ceil(H / CELL) + 2; total = cols * rows;
      buildOrder(); ptr = 0; spawned = 0; filled.length = 0; gridDisplayed = 0;
    }

    function bootFill() { resizeCanvas(); rebuildGrid(); }
    bootFill();

    function spawnCellsToTarget(targetCount) {
      var cap = Math.min(targetCount, indices.length);
      while (spawned < cap) {
        var id = indices[ptr++].id, c = id % cols, r = (id / cols) | 0;
        filled.push({ x: c*CELL - CELL, y: r*CELL - CELL }); spawned++;
      }
    }

    function computeEffectiveProgress(now) {
      var activeNow = getActiveTime(now);
      var bp = boot._targetProgress || 0;
      progressFromMilestones = bp / 100;
      if (bp !== lastMilestoneValue) { lastMilestoneChange = activeNow; lastMilestoneValue = bp; }
      var target = progressFromMilestones;
      var stuck = activeNow - lastMilestoneChange;
      if (stuck > 3000) target = Math.min(1, progressFromMilestones + (stuck - 3000) * 0.003);
      return target;
    }

    function syncProgressToTimeline(now) {
      var ep = computeEffectiveProgress(now);
      if (ep > displayedProgress) displayedProgress += (ep - displayedProgress) * 0.12;
      if (Math.abs(ep - displayedProgress) < 0.001) displayedProgress = ep;
      var dp = Math.min(1, displayedProgress);
      var counter = Math.min(50, Math.floor(dp * 50));
      if (counter !== lastCounter) { lastCounter = counter; counterEl.textContent = String(counter).padStart(2, "0"); }
      if (progressEl) {
        var pct = Math.round(dp * 100);
        if (pct !== lastProgress) { lastProgress = pct; progressEl.textContent = pct + "%"; }
      }
      var bp = boot._targetProgress || 0;
      if (bp >= 100) {
        if (ep > gridDisplayed) gridDisplayed += (ep - gridDisplayed) * 0.12;
        if (Math.abs(ep - gridDisplayed) < 0.001) gridDisplayed = ep;
      }
      var gdp = Math.min(1, gridDisplayed);
      var tgt = gdp >= 1 ? total : Math.floor(gdp * total);
      spawnCellsToTarget(tgt);
    }

    function onBootTimelineComplete() {
      if (chromeRemoved) return;
      chromeRemoved = true;
      overlay.style.pointerEvents = "none";
      boot.animationDone = true;
      boot._try();
    }

    function drawMask() {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.imageSmoothingEnabled = false;
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = "#FF0000";
      ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "destination-out";
      ctx.fillStyle = "#000000";
      var hole = CELL;
      for (var k = 0; k < filled.length; k++) {
        var cell = filled[k];
        ctx.fillRect(Math.floor(cell.x) - 1, Math.floor(cell.y) - 1, hole + 2, hole + 2);
      }
      ctx.globalCompositeOperation = "source-over";
    }

    function tick() {
      if (isHidden) { rafId = 0; return; }
      if (!document.body.contains(overlay) || overlay.getAttribute("data-state") === "done") {
        if (rafId) cancelAnimationFrame(rafId); return;
      }
      var now = performance.now();
      syncProgressToTimeline(now);
      if (now >= bootStartTime + 15000 && gridDisplayed < 1) { gridDisplayed = 1; spawnCellsToTarget(total); }
      if (gridDisplayed >= 0.995 && !chromeRemoved) onBootTimelineComplete();
      drawMask();
      rafId = requestAnimationFrame(tick);
    }

    window.addEventListener("resize", function () {
      if (!document.body.contains(overlay) || overlay.getAttribute("data-state") === "done") return;
      resizeCanvas();
      // While still filling, restart the grid at the new size; once essentially
      // complete keep the existing holes (canvas just gets a new backing store).
      if (spawned < total * 0.98) rebuildGrid();
    });
    rafId = requestAnimationFrame(tick);
    bootAnim = { tick: tick };
  }

  // ======================================================================
  // 3. WebGL helpers
  // ======================================================================

  function getGL(canvas) {
    return WEBGL2 ? canvas.getContext("webgl2") : null;
  }

  function compileShader(gl, type, src) {
    var sh = gl.createShader(type);
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
      gl.deleteShader(sh);
      return null;
    }
    return sh;
  }

  function linkProgram(gl, vs, fs) {
    var p = gl.createProgram();
    gl.attachShader(p, vs); gl.attachShader(p, fs);
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
      gl.deleteProgram(p);
      return null;
    }
    return p;
  }

  // Column-major 4x4 matrix helpers (matching reference's LM.purs convention).
  function M4I() { return new Float32Array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]); }
  function M4Mult(a, b) {
    var o = new Float32Array(16);
    for (var i = 0; i < 4; i++) for (var j = 0; j < 4; j++) {
      var s = 0;
      for (var k = 0; k < 4; k++) s += a[k*4+j] * b[i*4+k];
      o[i*4+j] = s;
    }
    return o;
  }
  function M4RotY(a) { var s=Math.sin(a),c=Math.cos(a); return new Float32Array([c,0,-s,0, 0,1,0,0, s,0,c,0, 0,0,0,1]); }
  function M4RotX(a) { var s=Math.sin(a),c=Math.cos(a); return new Float32Array([1,0,0,0, 0,c,s,0, 0,-s,c,0, 0,0,0,1]); }
  function M4Trans(x,y,z) { var m=M4I(); m[12]=x; m[13]=y; m[14]=z; return m; }
  function M4Perspective(fovy, aspect, near, far) {
    var f = 1 / Math.tan(fovy / 2);
    var nf = 1 / (near - far);
    return new Float32Array([
      f/aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far+near)*nf, -1,
      0, 0, 2*far*near*nf, 0,
    ]);
  }

  // ======================================================================
  // 4. WebGL cube logo (port of Components/Logo + Logo.FFI + shaders)
  // ======================================================================

  // 24 verts (6 faces x 4), 36 indices, half-extent s=1.25.
  function cubeGeom(s) {
    var f=[[-s,-s,s],[s,-s,s],[s,s,s],[-s,s,s]];
    var b=[[s,-s,-s],[-s,-s,-s],[-s,s,-s],[s,s,-s]];
    var r=[[s,-s,-s],[s,-s,s],[s,s,s],[s,s,-s]];
    var l=[[-s,-s,s],[-s,-s,-s],[-s,s,-s],[-s,s,s]];
    var t=[[-s,s,-s],[s,s,-s],[s,s,s],[-s,s,s]];
    var u=[[-s,-s,s],[s,-s,s],[s,-s,-s],[-s,-s,-s]];
    var pos=[].concat(f,b,r,l,t,u);
    var norm=[]; function N(nx,ny,nz){for(var i=0;i<4;i++)norm.push(nx,ny,nz);}
    N(0,0,1); N(0,0,-1); N(1,0,0); N(-1,0,0); N(0,1,0); N(0,-1,0);
    var idx=[]; for(var q=0;q<6;q++){var o=q*4; idx.push(o,o+1,o+2, o,o+2,o+3);}
    return { pos: new Float32Array(pos.flat ? pos.flat() : [].concat.apply([], pos)),
             norm: new Float32Array(norm), idx: new Uint16Array(idx), nIdx: idx.length };
  }

  var CUBE_VS =
    "#version 300 es\n" +
    "in vec3 aPosition;\n" +
    "in vec3 aNormal;\n" +
    "uniform mat4 uProjection;\n" +
    "uniform mat4 uModelView;\n" +
    "out vec3 vNormal;\n" +
    "out vec3 vPosition;\n" +
    "void main(){\n" +
    "  mat3 nm = mat3(uModelView);\n" +
    "  vNormal = normalize(nm * aNormal);\n" +
    "  vec4 mv = uModelView * vec4(aPosition, 1.0);\n" +
    "  vPosition = mv.xyz;\n" +
    "  gl_Position = uProjection * mv;\n" +
    "}\n";

  // Bayer 8x8 dithering, two-tone shading (matches reference's logo fragment shader).
  var CUBE_FS =
    "#version 300 es\n" +
    "precision mediump float;\n" +
    "uniform vec3 uColorLight;\n" +
    "uniform vec3 uColorDark;\n" +
    "uniform vec3 uLightPosition;\n" +
    "in vec3 vNormal;\n" +
    "in vec3 vPosition;\n" +
    "out vec4 o;\n" +
    "float bayer(vec2 p){\n" +
    "  vec2 q = mod(p, 8.0);\n" +
    "  float r = 0.0; float w = 32.0; float d = 1.0;\n" +
    "  for (int i = 0; i < 3; i++){\n" +
    "    vec2 b = mod(floor(q / d), 2.0);\n" +
    "    r += (b.x + b.y - 2.0 * b.x * b.y) * w;\n" +
    "    w *= 0.5;\n" +
    "    r += b.y * w;\n" +
    "    w *= 0.5;\n" +
    "    d *= 2.0;\n" +
    "  }\n" +
    "  return r / 64.0;\n" +
    "}\n" +
    "void main(){\n" +
    "  vec3 L = normalize(uLightPosition - vPosition);\n" +
    "  float diffuse = max(dot(vNormal, L), 0.0);\n" +
    "  float intensity = diffuse * 0.6;\n" +
    "  float th = bayer(gl_FragCoord.xy);\n" +
    "  vec3 c = intensity > th ? uColorLight : uColorDark;\n" +
    "  o = vec4(c, 1.0);\n" +
    "}\n";

  function mountCube(host) {
    if (!WEBGL2) { host.setAttribute("data-gfx-failed", "1"); return; }
    var size = parseInt(host.getAttribute("data-logo-px") || "36", 10);
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var canvas = document.createElement("canvas");
    canvas.style.cssText = "display:block;width:100%;height:100%;touch-action:none;pointer-events:none;";
    canvas.width = size * dpr; canvas.height = size * dpr;
    host.appendChild(canvas);
    var gl = getGL(canvas);
    if (!gl) { host.setAttribute("data-gfx-failed", "1"); return; }
    var vs = compileShader(gl, gl.VERTEX_SHADER, CUBE_VS);
    var fs = compileShader(gl, gl.FRAGMENT_SHADER, CUBE_FS);
    if (!vs || !fs) { host.setAttribute("data-gfx-failed", "1"); return; }
    var prog = linkProgram(gl, vs, fs);
    if (!prog) { host.setAttribute("data-gfx-failed", "1"); return; }
    gl.useProgram(prog);
    var g = cubeGeom(1.25);
    var pBuf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, pBuf); gl.bufferData(gl.ARRAY_BUFFER, g.pos, gl.STATIC_DRAW);
    var nBuf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, nBuf); gl.bufferData(gl.ARRAY_BUFFER, g.norm, gl.STATIC_DRAW);
    var iBuf = gl.createBuffer(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, iBuf); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, g.idx, gl.STATIC_DRAW);
    var aPos = gl.getAttribLocation(prog, "aPosition");
    var aNorm = gl.getAttribLocation(prog, "aNormal");
    gl.bindBuffer(gl.ARRAY_BUFFER, pBuf); gl.enableVertexAttribArray(aPos); gl.vertexAttribPointer(aPos, 3, gl.FLOAT, false, 0, 0);
    gl.bindBuffer(gl.ARRAY_BUFFER, nBuf); gl.enableVertexAttribArray(aNorm); gl.vertexAttribPointer(aNorm, 3, gl.FLOAT, false, 0, 0);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, iBuf);
    var uProj = gl.getUniformLocation(prog, "uProjection");
    var uMV = gl.getUniformLocation(prog, "uModelView");
    var uCL = gl.getUniformLocation(prog, "uColorLight");
    var uCD = gl.getUniformLocation(prog, "uColorDark");
    var uLP = gl.getUniformLocation(prog, "uLightPosition");
    gl.enable(gl.DEPTH_TEST);
    gl.viewport(0, 0, canvas.width, canvas.height);
    var proj = M4Perspective(50 * Math.PI / 180, 1, 0.1, 100);
    var view = M4Trans(0, 0, -5);
    gl.uniform3f(uCL, 1.0, 0.29, 0.15);
    gl.uniform3f(uCD, 0.10, 0.10, 0.10);
    gl.uniform3f(uLP, 50, 50, 45);
    gl.uniformMatrix4fv(uProj, false, proj);

    var running = true, raf = 0, t0 = performance.now();
    function draw(t) {
      if (!running) return;
      var elapsed = (t - t0) / 1000;
      var model = M4Mult(M4RotY(elapsed * 0.2), M4RotX(elapsed * 0.2));
      var mv = M4Mult(view, model);
      gl.uniformMatrix4fv(uMV, false, mv);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      gl.drawElements(gl.TRIANGLES, g.nIdx, gl.UNSIGNED_SHORT, 0);
      raf = requestAnimationFrame(draw);
    }
    raf = requestAnimationFrame(draw);

    boot.markLogo();

    var io = new IntersectionObserver(function (entries) {
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].isIntersecting) { if (!running) { running = true; raf = requestAnimationFrame(draw); } }
        else { running = false; cancelAnimationFrame(raf); }
      }
    }, { threshold: 0 });
    io.observe(host);
    if (reduceMotion) { running = false; cancelAnimationFrame(raf); }
  }

  // ======================================================================
  // 5. WebGL sea (port of sea-footer.frag.glsl, no-texture variant)
  // ======================================================================

  // Fullscreen triangle vertex shader (WebGL 2, no attributes needed).
  var SEA_VS =
    "#version 300 es\n" +
    "void main(){\n" +
    "  vec2 p = vec2((gl_VertexID == 1) ? 3.0 : -1.0, (gl_VertexID == 2) ? 3.0 : -1.0);\n" +
    "  gl_Position = vec4(p, 0.0, 1.0);\n" +
    "}\n";

  // Port of sea-footer.frag.glsl (no USE_TEXTURE_NOISE branch). Identical math.
  var SEA_FS =
    "#version 300 es\n" +
    "precision highp float;\n" +
    "out vec4 o;\n" +
    "uniform float t;\n" +
    "uniform vec2 r;\n" +
    "uniform vec2 cubeOff;\n" +
    "uniform vec2 cubeVel;\n" +
    "uniform float cloudQ;\n" +
    "uniform float uiDark;\n" +
    "uniform float seaIntro;\n" +
    "const float LCL_PARAM=2.50;\n" +
    "const float WAVE_PARAM=2.70;\n" +
    "const float SHORE_PARAM=0.80;\n" +
    "const float TOR2_SC=1.65;\n" +
    "const float WAVE_K = 0.78*0.25*WAVE_PARAM;\n" +
    "const float INV_PI = 0.31830988618;\n" +
    "float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}\n" +
    "float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);}\n" +
    "float fbm(vec2 p){return n(p)*0.55+n(p*2.0)*0.3+n(p*4.0)*0.15;}\n" +
    "float cloudDensity(vec2 pos,float tm,float q){\n" +
    "  vec2 p1=pos*vec2(0.065,0.15)+vec2(tm*0.24,-tm*0.07);\n" +
    "  vec2 p2=pos*vec2(0.10,0.19)+vec2(-tm*0.19,tm*0.06);\n" +
    "  float n1=fbm(p1); float n2=fbm(p2*0.94);\n" +
    "  float carve=fbm(pos*vec2(0.45,0.85)+vec2(tm*0.28,-tm*0.10));\n" +
    "  carve=smoothstep(0.38,0.62,carve);\n" +
    "  float c1=smoothstep(0.62,0.78,n1); float c2=smoothstep(0.64,0.80,n2);\n" +
    "  float clumps=max(c1,c2)*mix(0.35,1.0,carve);\n" +
    "  return pow(clamp(clumps,0.0,1.0), mix(1.15,1.35,q));\n" +
    "}\n" +
    "float sdBox3(vec3 p,vec3 b){vec3 q=abs(p)-b;return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0);}\n" +
    "float rayBoxOffset(vec3 roL,vec3 rdL,vec3 off,vec3 hb){\n" +
    "  vec3 roB=roL-off; vec3 m=1.0/(rdL+1e-6);\n" +
    "  vec3 t1=(-hb-roB)*m; vec3 t2=(hb-roB)*m;\n" +
    "  vec3 tmi=min(t1,t2); vec3 tma=max(t1,t2);\n" +
    "  float tN=max(max(tmi.x,tmi.y),tmi.z); float tF=min(min(tma.x,tma.y),tma.z);\n" +
    "  return (tN<tF && tF>0.0 && tN>0.0 && tN<1e4) ? tN : -1.0;\n" +
    "}\n" +
    "float dToriiPl(vec3 p){\n" +
    "  float d=1e9;\n" +
    "  d=min(d,sdBox3(p-vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032)));\n" +
    "  d=min(d,sdBox3(p-vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032)));\n" +
    "  d=min(d,sdBox3(p-vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062)));\n" +
    "  d=min(d,sdBox3(p-vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052)));\n" +
    "  return d;\n" +
    "}\n" +
    "vec3 norToriiPl(vec3 p){float e=0.002;float a=dToriiPl(p);return normalize(vec3(dToriiPl(p+vec3(e,0.0,0.0))-a,dToriiPl(p+vec3(0.0,e,0.0))-a,dToriiPl(p+vec3(0.0,0.0,e))-a));}\n" +
    "vec3 toriiWoodGrain(vec3 p,vec3 nrm){\n" +
    "  vec3 gv=vec3(0.0);\n" +
    "  for(int i=0;i<3;i++){float f=1.0+float(i)*0.8;float g=n(p.xz*f*28.0)*0.5+n(p.xz*f*55.0)*0.25;float ge=n((p.xz*f+vec2(0.008,0.0))*28.0)*0.5+n((p.xz*f+vec2(0.008,0.0))*55.0)*0.25;float gn=n((p.xz*f+vec2(0.0,0.008))*28.0)*0.5+n((p.xz*f+vec2(0.0,0.008))*55.0)*0.25;gv+=vec3(ge-g,0.0,gn-g)*f;}\n" +
    "  return normalize(nrm+vec3(gv.x*0.06,0.0,gv.z*0.06));\n" +
    "}\n" +
    "float rayToriiT(vec3 ro,vec3 rd,vec3 cen,mat3 rot){\n" +
    "  vec3 roL=transpose(rot)*(ro-cen); vec3 rdL=transpose(rot)*rd;\n" +
    "  float tB=-1.0,tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  return tB;\n" +
    "}\n" +
    "float rayToriiTSc(vec3 ro,vec3 rd,vec3 cen,mat3 rot,float sc){\n" +
    "  vec3 roL=(transpose(rot)*(ro-cen))/sc; vec3 rdL=(transpose(rot)*rd)/sc;\n" +
    "  float tB=-1.0,tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052)); if(tm>0.0&&(tB<0.0||tm<tB)) tB=tm;\n" +
    "  return tB;\n" +
    "}\n" +
    "mat3 rotX(float a){float s=sin(a),c=cos(a);return mat3(1.0,0.0,0.0, 0.0,c,-s, 0.0,s,c);}\n" +
    "mat3 rotY(float a){float s=sin(a),c=cos(a);return mat3(c,0.0,s, 0.0,1.0,0.0, -s,0.0,c);}\n" +
    "mat3 rotZ(float a){float s=sin(a),c=cos(a);return mat3(c,-s,0.0, s,c,0.0, 0.0,0.0,1.0);}\n" +
    "float wave(vec2 p,float tm){float w=0.0;w+=sin(p.x*0.9+p.y*1.1-tm*1.7)*0.48;w+=sin(p.x*1.4-p.y*0.8+tm*1.2)*0.34;w+=sin(p.x*2.3+p.y*1.9+tm*0.9)*0.22;w+=sin(p.x*3.7-p.y*2.6-tm*1.5)*0.12;w+=sin(p.x*6.4+p.y*3.1-tm*2.3)*0.06;w+=sin(p.x*5.2-tm*2.4)*sin(p.y*2.8+tm*1.7)*0.06;return w;}\n" +
    "vec3 seaNormalFbm(vec2 p,float tm){vec2 e=vec2(0.003,0.0);return normalize(vec3((wave(p-e.xy,tm)-wave(p+e.xy,tm))*WAVE_K/e.x*0.5, 1.0, (wave(p-e.yx,tm)-wave(p+e.yx,tm))*WAVE_K/e.x*0.5));}\n" +
    "float ggxD(float NdotH,float rough){float a=rough*rough;float a2=a*a;float d=(NdotH*NdotH)*(a2-1.0)+1.0;return a2*INV_PI/(d*d);}\n" +
    "float ggxG(float NdotV,float NdotL,float rough){float r=rough+1.0;float k=(r*r)/8.0;return NdotV/(NdotV*(1.0-k)+k)*NdotL/(NdotL*(1.0-k)+k);}\n" +
    "float ggxF0(float NdotH,float NdotV,float NdotL,float f0){float f=f0+(1.0-f0)*pow(1.0-max(NdotH,0.0),5.0);return f*(NdotL*0.2+0.8)+(1.0-NdotL)*0.2;}\n" +
    "void main(){\n" +
    "  vec2 uv=(gl_FragCoord.xy-0.5*r)/r.y;\n" +
    "  float camT=smoothstep(0.0,1.0,clamp(seaIntro,0.0,1.0));\n" +
    "  vec3 ro=mix(vec3(0.0,2.5,-30.0), vec3(0.0,1.8,-7.5), camT);\n" +
    "  vec3 rd=normalize(vec3(uv,1.6)); rd=rotX(0.05)*rd;\n" +
    "  float isSky=step(0.26,rd.y); float time=t*0.85; float D=uiDark;\n" +
    "  vec3 pageBg=vec3(0.090196); vec3 skyPaper=mix(vec3(1.0),pageBg,D);\n" +
    "  vec3 col=skyPaper; float isSea=0.0; vec3 seaOnly=vec3(0.0);\n" +
    "  if(isSky<0.5){\n" +
    "    vec2 cubeDrift=vec2(sin(time*0.18)*0.32+sin(time*0.07+1.3)*0.10, cos(time*0.14)*0.18+sin(time*0.05)*0.08);\n" +
    "    vec2 cubeXZ=vec2(0.0,13.2)+cubeDrift+cubeOff;\n" +
    "    float wCube=wave(cubeXZ*0.65,time);\n" +
    "    float waterAtCube=wCube*0.72*0.22*(0.55+0.45*WAVE_PARAM);\n" +
    "    float perspZ=clamp((cubeXZ.y-4.0)/12.0,0.0,1.0); float size=mix(1.05,0.45,perspZ); float fl=0.06;\n" +
    "    float cubeShoreZ=SHORE_PARAM+wCube*WAVE_K*0.95;\n" +
    "    float seaDepth=clamp((cubeXZ.y-cubeShoreZ)/3.0,0.0,1.0); float bob=0.7*seaDepth;\n" +
    "    float cubeBaseY=waterAtCube-size*0.35+fl+mix(size*0.55,0.0,seaDepth);\n" +
    "    float bobY=sin(time*0.42+cubeXZ.x*0.35)*0.015*bob+cos(time*0.31-cubeXZ.y*0.26)*0.010*bob;\n" +
    "    vec3 cubePos=vec3(cubeXZ.x,cubeBaseY+bobY,cubeXZ.y);\n" +
    "    float ang=0.785398+sin(time*0.32)*0.12+cos(time*0.21)*0.05;\n" +
    "    float tiltZ=clamp(cubeVel.x*-0.15,-0.25,0.25)*mix(0.2,1.0,seaDepth);\n" +
    "    float tiltX=clamp(cubeVel.y*0.10,-0.20,0.20)*mix(0.2,1.0,seaDepth);\n" +
    "    float waveTilt=bobY*0.8*seaDepth;\n" +
    "    mat3 cubeRot=rotY(ang)*rotX(0.14+sin(time*0.8)*0.06*seaDepth+waveTilt+tiltX)*rotZ(0.09+cos(time*0.6)*0.04*seaDepth+tiltZ);\n" +
    "    float th=-ro.y/rd.y; float seaClip=(rd.y<0.0)?th:1e9; vec3 hit=ro+rd*((th>0.0)?th:1e-3); vec2 p=hit.xz;\n" +
    "    float wSea=wave(p*0.65,time);\n" +
    "    float seaSurf=wSea*WAVE_K;\n" +
    "    float shorePulse=sin(p.x*0.8-time*0.9)*0.06+sin(p.x*2.2+time*1.7)*0.025;\n" +
    "    float shoreZ=SHORE_PARAM+seaSurf*0.95+shorePulse;\n" +
    "    float dist=p.y-shoreZ; isSea=step(0.0,dist);\n" +
    "    float depthTint=clamp(dist*0.42,0.0,3.0);\n" +
    "    vec3 seaShallow=vec3(1.0,0.38,0.48); vec3 seaMid=vec3(0.97,0.22,0.33); vec3 seaDeep=vec3(0.82,0.11,0.19);\n" +
    "    seaOnly=mix(seaShallow,seaMid,smoothstep(0.0,0.7,depthTint));\n" +
    "    seaOnly=mix(seaOnly,seaDeep,smoothstep(0.7,2.1,depthTint));\n" +
    "    vec3 roC=transpose(cubeRot)*(ro-cubePos); vec3 rdC=transpose(cubeRot)*rd;\n" +
    "    vec3 b=vec3(size); vec3 m=1.0/(rdC+1e-6); vec3 t1=(-b-roC)*m; vec3 t2=(b-roC)*m;\n" +
    "    vec3 tmin2=min(t1,t2); vec3 tmax2=max(t1,t2);\n" +
    "    float tN=max(max(tmin2.x,tmin2.y),tmin2.z); float tF=min(min(tmax2.x,tmax2.y),tmax2.z);\n" +
    "    bool hitCubeV=(tN<tF && tF>0.0 && tN>0.0 && tN<seaClip);\n" +
    "    float torFarZ=26.2;\n" +
    "    vec2 tor0XZ=vec2(-10.8,torFarZ); vec2 tor1XZ=vec2(10.8,torFarZ); vec2 tor2XZ=vec2(0.0,35.0);\n" +
    "    float wT0=wave(tor0XZ*0.65,0.0)*0.72*0.22*(0.55+0.45*WAVE_PARAM);\n" +
    "    float wT1=wave(tor1XZ*0.65,0.0)*0.72*0.22*(0.55+0.45*WAVE_PARAM);\n" +
    "    float wT2=wave(tor2XZ*0.65,0.0)*0.72*0.22*(0.55+0.45*WAVE_PARAM);\n" +
    "    vec3 tor0Pos=vec3(tor0XZ.x,wT0,tor0XZ.y); vec3 tor1Pos=vec3(tor1XZ.x,wT1,tor1XZ.y); vec3 tor2Pos=vec3(tor2XZ.x,wT2,tor2XZ.y);\n" +
    "    mat3 tor0Rot=rotY(0.62)*rotX(0.05)*rotZ(0.03);\n" +
    "    mat3 tor1Rot=rotY(-0.58)*rotX(0.05)*rotZ(-0.03);\n" +
    "    mat3 tor2Rot=rotY(0.04)*rotX(0.04)*rotZ(0.0);\n" +
    "    float tTor0=rayToriiT(ro,rd,tor0Pos,tor0Rot);\n" +
    "    float tTor1=rayToriiT(ro,rd,tor1Pos,tor1Rot);\n" +
    "    float tTor2=rayToriiTSc(ro,rd,tor2Pos,tor2Rot,TOR2_SC);\n" +
    "    float tTor=1e9; int tid=0;\n" +
    "    if(tTor0>0.0){tTor=tTor0; tid=0;}\n" +
    "    if(tTor1>0.0 && tTor1<tTor){tTor=tTor1; tid=1;}\n" +
    "    if(tTor2>0.0 && tTor2<tTor){tTor=tTor2; tid=2;}\n" +
    "    if(tTor>1e8) tTor=-1.0;\n" +
    "    float tBest=1e9; int hid=-1;\n" +
    "    if(th>0.0 && rd.y<0.0){tBest=th; hid=0;}\n" +
    "    if(hitCubeV && tN<tBest){tBest=tN; hid=1;}\n" +
    "    if(tTor>=0.0 && tTor<tBest){tBest=tTor; hid=2;}\n" +
    "    if(hid==-1) isSea=0.0;\n" +
    "    vec3 Lsun=normalize(vec3(0.3,0.8,0.4));\n" +
    "    if(hid==1){\n" +
    "      vec3 ch=ro+rd*tN; vec3 pc=transpose(cubeRot)*(ch-cubePos); vec3 ap=abs(pc); vec3 nrm=vec3(0.0);\n" +
    "      if(ap.x>ap.y && ap.x>ap.z) nrm.x=sign(pc.x); else if(ap.y>ap.z) nrm.y=sign(pc.y); else nrm.z=sign(pc.z);\n" +
    "      nrm=normalize(cubeRot*nrm); vec3 base=vec3(1.0);\n" +
    "      float top=max(0.0,nrm.y*0.5+0.5); float side=pow(max(0.0,abs(nrm.x)*0.6+abs(nrm.z)*0.4),1.2); float fres=pow(1.0-max(0.0,dot(nrm,-rd)),2.4);\n" +
    "      float stain=fbm(pc.xz*3.2+vec2(time*0.08,-time*0.06));\n" +
    "      vec3 stainTint=mix(vec3(1.0),vec3(0.82,0.84,0.88),smoothstep(0.35,0.90,stain));\n" +
    "      col=base*stainTint*(0.58+top*0.42); col+=vec3(0.86,0.88,0.92)*side*0.16; col+=vec3(1.0,0.99,1.0)*fres*0.36;\n" +
    "      float wetLine=ch.y-waterAtCube; float subm=1.0-smoothstep(-0.02,0.04,wetLine);\n" +
    "      col=mix(col,col*0.85+vec3(0.06,0.07,0.09),subm*0.45); col+=exp(-abs(wetLine)*80.0)*0.10*vec3(1.0,0.99,1.0);\n" +
    "      float spec=pow(max(0.0,dot(reflect(-Lsun,nrm),-rd)),64.0); col+=spec*0.35*vec3(1.0,0.9,0.95);\n" +
    "      isSea=0.0;\n" +
    "    } else if(hid==2){\n" +
    "      vec3 ch=ro+rd*tTor; vec3 torCen=tor0Pos; mat3 torR=tor0Rot; float wTw=wT0;\n" +
    "      if(tid==1){torCen=tor1Pos; torR=tor1Rot; wTw=wT1;} else if(tid==2){torCen=tor2Pos; torR=tor2Rot; wTw=wT2;}\n" +
    "      float tsc=(tid==2)?TOR2_SC:1.0; vec3 pl=transpose(torR)*(ch-torCen)/tsc;\n" +
    "      vec3 nrmL=norToriiPl(pl); vec3 nrm=normalize(torR*nrmL);\n" +
    "      nrm=mix(nrm,toriiWoodGrain(pl,nrm),0.35);\n" +
    "      vec3 base=vec3(0.62,0.12,0.09);\n" +
    "      float top=max(0.0,nrm.y*0.5+0.5); float side=pow(max(0.0,abs(nrm.x)*0.55+abs(nrm.z)*0.45),1.15); float fres=pow(1.0-max(0.0,dot(nrm,-rd)),2.1);\n" +
    "      col=base*(0.48+top*0.42); col+=vec3(0.78,0.22,0.14)*side*0.28; col+=vec3(0.88,0.42,0.32)*fres*0.36;\n" +
    "      float wetLine=ch.y-wTw; float subm=1.0-smoothstep(-0.02,0.04,wetLine);\n" +
    "      col=mix(col,col*0.82+vec3(0.07,0.02,0.02),subm*0.42); col+=exp(-abs(wetLine)*80.0)*0.09*vec3(0.98,0.55,0.42);\n" +
    "      float spec=pow(max(0.0,dot(reflect(-Lsun,nrm),-rd)),56.0); col+=spec*0.28*vec3(1.0,0.72,0.55);\n" +
    "      float rim=pow(max(0.0,1.0-abs(dot(nrm,rd))),3.0)*0.45; col+=rim*vec3(1.0,0.48,0.28)*(0.5+0.5*smoothstep(0.3,0.7,pl.y));\n" +
    "      isSea=0.0;\n" +
    "    } else if(hid==0){\n" +
    "      vec3 sand=mix(vec3(1.0),pageBg*1.02,D); sand+=(fbm(p*11.0)-0.5)*0.008;\n" +
    "      float depth=clamp(dist*0.42,0.0,3.0);\n" +
    "      vec3 seaShallow=vec3(1.0,0.38,0.48); vec3 seaMid=vec3(0.97,0.22,0.33); vec3 seaDeep=vec3(0.82,0.11,0.19);\n" +
    "      vec3 sea=mix(seaShallow,seaMid,smoothstep(0.0,0.7,depth));\n" +
    "      sea=mix(sea,seaDeep,smoothstep(0.7,2.1,depth));\n" +
    "      vec2 luv=p*1.5; float lclA=pow(fbm(luv+vec2(time*0.30,-time*0.08)),9.5);\n" +
    "      float lclB=pow(fbm(luv*1.9-vec2(time*0.22,time*0.05)),12.0);\n" +
    "      float lcl=clamp(lclA*0.70+lclB*0.45,0.0,1.0);\n" +
    "      float lclDark=0.45*D; vec3 lclCoral=mix(vec3(1.0,0.66,0.46),vec3(0.20,0.17,0.16),lclDark);\n" +
    "      vec3 lclWarm=mix(vec3(1.0,0.82,0.66),vec3(0.24,0.20,0.18),lclDark);\n" +
    "      sea+=lcl*0.72*LCL_PARAM*lclCoral*isSea; sea+=pow(fbm(luv*3.3+time*0.18),13.6)*0.20*LCL_PARAM*lclWarm*isSea;\n" +
    "      col=mix(sand,sea,isSea);\n" +
    "      vec2 seaC0=p*vec2(0.071,0.056)+vec2(time*0.055,-time*0.02);\n" +
    "      vec2 seaC1=p*vec2(0.065,0.051)*0.92+vec2(-time*0.048,time*0.015);\n" +
    "      float sdSea0=cloudDensity(seaC0,time,cloudQ); float sdSea1=cloudDensity(seaC1,time+4.5,cloudQ);\n" +
    "      float cMix=max(sdSea0,sdSea1); float openW=smoothstep(0.08,1.4,dist*0.42)*isSea;\n" +
    "      float cMix2=cMix*cMix; float cSh=smoothstep(0.42,0.92,cMix)*(0.42+0.58*cMix2)*openW;\n" +
    "      float cRf=max(smoothstep(0.32,0.62,cMix)*(1.0-cSh*0.75),0.0)*openW;\n" +
    "      col*=mix(vec3(1.0),vec3(0.58,0.60,0.74),cSh*0.62); col+=cRf*vec3(0.06+0.04*cMix,0.065+0.035*cMix,0.085+0.04*cMix);\n" +
    "      float d=dist;\n" +
    "      vec3 seaN=seaNormalFbm(p,time); vec3 Hsun=Lsun+(-rd); float hLen=length(Hsun);\n" +
    "      vec3 halfVec=hLen>1e-4?Hsun/hLen:vec3(0.0,1.0,0.0);\n" +
    "      float NdotH=max(0.0,dot(seaN,halfVec)); float NdotV=max(0.0,dot(seaN,-rd));\n" +
    "      float NdotL=max(0.0,dot(seaN,Lsun));\n" +
    "      float rough=0.18+0.12*fbm(p*2.2+time*0.15); float f0=0.02;\n" +
    "      float Dggx=ggxD(NdotH,rough); float Gggx=ggxG(NdotV,NdotL,rough); float Fggx=ggxF0(NdotH,NdotV,NdotL,f0);\n" +
    "      float specGlint=Dggx*Gggx*Fggx*0.42*isSea*smoothstep(0.0,0.35,dist);\n" +
    "      col+=specGlint*vec3(1.0,0.92,0.88);\n" +
    "      if(cloudQ>0.385){\n" +
    "        vec3 seaNh2=seaNormalFbm(p*1.8,time); float NdotH2=max(0.0,dot(seaNh2,halfVec));\n" +
    "        float D2=ggxD(NdotH2,rough*0.65); float G2=ggxG(NdotV,NdotL,rough*0.65);\n" +
    "        float F2=ggxF0(NdotH2,NdotV,NdotL,f0);\n" +
    "        float specGlint2=D2*G2*F2*0.28*isSea*smoothstep(0.0,0.5,dist);\n" +
    "        col+=specGlint2*vec3(1.0,0.85,0.78);\n" +
    "      }\n" +
    "    }\n" +
    "  }\n" +
    "  float cloudH=-uv.y; float cloudBand=smoothstep(0.0,0.018,cloudH)*(1.0-smoothstep(0.055,0.20,cloudH));\n" +
    "  float cq=clamp(cloudQ,0.2,1.0); vec2 scBase=vec2(uv.x*7.5,cloudH*22.0);\n" +
    "  vec2 cd0UV=scBase+vec2(time*0.055,-time*0.02); vec2 cd1UV=scBase*0.92+vec2(-time*0.048,time*0.015);\n" +
    "  vec2 cd2UV=scBase*0.84+vec2(time*0.034,time*0.011);\n" +
    "  float sd0=cloudDensity(cd0UV,time,cq); float sd1=cloudDensity(cd1UV,time+4.5,cq);\n" +
    "  float sd2=cloudDensity(cd2UV,time+9.0,cq);\n" +
    "  float sa0=smoothstep(0.48,0.82,sd0); float sa1=smoothstep(0.50,0.84,sd1); float sa2=smoothstep(0.52,0.86,sd2);\n" +
    "  float heightGrad=1.0-smoothstep(0.025,0.16,cloudH);\n" +
    "  vec3 seaTint=mix(col,seaOnly,0.0); float lowerW=(1.0-heightGrad);\n" +
    "  vec3 cloudBot=vec3(0.90,0.88,0.91); vec3 botCol=mix(cloudBot,seaTint,isSea*0.20*lowerW);\n" +
    "  vec3 cloudTop=mix(vec3(1.0),seaTint,isSea*0.06);\n" +
    "  vec3 cc0=mix(botCol,cloudTop,heightGrad); float cMask=cloudBand*mix(0.5,1.0,cq);\n" +
    "  float cw=mix(0.62,1.0,cq);\n" +
    "  col=mix(col,cc0,sa0*cMask*0.72*cw);\n" +
    "  vec3 cc1=mix(botCol*0.97,cloudTop*0.98,heightGrad)*(1.0-sa0*0.20);\n" +
    "  col=mix(col,cc1,sa1*(1.0-sa0*0.55)*cMask*0.58*cw);\n" +
    "  vec3 cc2=mix(botCol*0.94,cloudTop*0.96,heightGrad)*(1.0-sa0*0.16)*(1.0-sa1*0.14);\n" +
    "  col=mix(col,cc2,sa2*(1.0-sa0*0.45)*(1.0-sa1*0.35)*cMask*0.48*cw);\n" +
    "  float cCore=smoothstep(0.82,0.97,sd0)*cMask*mix(0.35,1.0,cq);\n" +
    "  vec3 coreCol=mix(vec3(1.0),seaTint,isSea*0.04);\n" +
    "  col=mix(col,coreCol,cCore*0.62); col+=seaTint*sa0*cMask*isSea*0.035*lowerW;\n" +
    "  col=clamp(col,0.0,1.0);\n" +
    "  float skyA=1.0-smoothstep(0.34,0.99,rd.y); float outASky=mix(1.0,skyA,isSky);\n" +
    "  float outA=mix(outASky,1.0,D); o=vec4(col,outA);\n" +
    "}\n";

  function mountSea(canvas) {
    boot.markPhase("sea_mount", 1);
    boot.markPhase("sea_start", 3);
    if (!WEBGL2) { canvas.setAttribute("data-sea-footer-error", "1"); boot.markSea(); return; }
    var gl = getGL(canvas);
    if (!gl) { canvas.setAttribute("data-sea-footer-error", "1"); boot.markSea(); return; }
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var coarse = matchMedia ? matchMedia("(pointer: coarse)").matches : false;
    var mobileW = matchMedia ? matchMedia("(max-width: 768px)").matches : false;
    var touch = coarse || mobileW || (navigator.maxTouchPoints > 0);
    var saveData = navigator.connection && navigator.connection.saveData;
    var dpr = Math.min(window.devicePixelRatio || 1, saveData ? 1 : mobileW ? 2 : touch ? 1.28 : 2);

    var cssW = 1, cssH = 1, dprCur = 0, drW = 0, drH = 0;
    function resize() {
      var r = canvas.getBoundingClientRect();
      var w = Math.max(1, r.width), h = Math.max(1, r.height);
      var z = Math.min(window.devicePixelRatio || 1, saveData ? 1 : mobileW ? 2 : touch ? 1.28 : 2);
      var dw = Math.abs(w - drW), dh = Math.abs(h - drH);
      if (dw < 12 && dh < 12 && Math.abs(z - dprCur) < 0.01) return;
      drW = w; drH = h; dprCur = z; cssW = w; cssH = h;
      canvas.width = Math.max(1, Math.round(w * z));
      canvas.height = Math.max(1, Math.round(h * z));
      gl.viewport(0, 0, canvas.width, canvas.height);
    }
    resize();
    new ResizeObserver(function () { resize(); }).observe(canvas);

    var vs = compileShader(gl, gl.VERTEX_SHADER, SEA_VS);
    boot.markPhase("sea_compile", 6);
    var fs = compileShader(gl, gl.FRAGMENT_SHADER, SEA_FS);
    if (!vs || !fs) { canvas.setAttribute("data-sea-footer-error", "1"); boot.markSea(); return; }
    var prog = linkProgram(gl, vs, fs);
    if (!prog) { canvas.setAttribute("data-sea-footer-error", "1"); boot.markSea(); return; }
    gl.useProgram(prog);
    boot.markPhase("sea_linked", 18);
    var uT = gl.getUniformLocation(prog, "t");
    var uR = gl.getUniformLocation(prog, "r");
    var uCubeOff = gl.getUniformLocation(prog, "cubeOff");
    var uCubeVel = gl.getUniformLocation(prog, "cubeVel");
    var uCloudQ = gl.getUniformLocation(prog, "cloudQ");
    var uDark = gl.getUniformLocation(prog, "uiDark");
    var uIntro = gl.getUniformLocation(prog, "seaIntro");
    var vao = gl.createVertexArray(); gl.bindVertexArray(vao);

    var cloudQ = saveData ? 0.22 : mobileW ? 0.45 : touch ? 0.35 : 0.6;
    gl.uniform1f(uCloudQ, cloudQ);

    // Grab-drag camera: mouseDown initiates a drag; window mousemove updates
    // cube position (clamped) with velocity; release decays velocity.
    var grabA = 0, grabB = 0;        // target cube position
    var smoothA = 0, smoothB = 0;    // smoothed for uCubeOff
    var prevA = 0, prevB = 0;        // last smoothed (for velocity)
    var velA = 0, velB = 0;          // for uCubeVel
    var grabbing = false, grabStartX = 0, grabStartY = 0, grabBaseA = 0, grabBaseB = 0;
    function grabStart(x, y) { grabbing = true; grabStartX = x; grabStartY = y; grabBaseA = grabA; grabBaseB = grabB; }
    function grabMove(x, y) {
      if (!grabbing) return;
      grabA = Math.max(-7, Math.min(7, grabBaseA + (x - grabStartX) / cssW * 10));
      grabB = Math.max(0, Math.min(11, grabBaseB - (y - grabStartY) / cssH * 8));
    }
    function grabEnd() { grabbing = false; }
    canvas.addEventListener("mousedown", function (e) { grabStart(e.clientX, e.clientY); e.preventDefault(); });
    window.addEventListener("mousemove", function (e) { grabMove(e.clientX, e.clientY); });
    window.addEventListener("mouseup", grabEnd);
    canvas.addEventListener("touchstart", function (e) { var t = e.touches[0]; grabStart(t.clientX, t.clientY); e.preventDefault(); }, { passive: false });
    window.addEventListener("touchmove", function (e) { if (grabbing) { var t = e.touches[0]; grabMove(t.clientX, t.clientY); } }, { passive: true });
    window.addEventListener("touchend", grabEnd);

    var t0 = performance.now(), running = true, raf = 0, mounted = false;
    var zt = 0, ir = null, seaIntroStart = null;
    var darkCur = document.documentElement.classList.contains("dark") ? 1 : 0;
    var darkLast = -1;
    if (typeof MutationObserver !== "undefined") {
      new MutationObserver(function () {
        darkCur = document.documentElement.classList.contains("dark") ? 1 : 0;
      }).observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
    }

    function draw(t) {
      if (!running) return;
      var dt = Math.min(0.05, (t - t0) / 1000); t0 = t;
      zt += dt;
      if (ir === null) ir = zt;
      smoothA += (grabA - smoothA) * 0.05;
      smoothB += (grabB - smoothB) * 0.05;
      var da = smoothA - prevA, db = smoothB - prevB;
      prevA = smoothA; prevB = smoothB;
      velA += (da * 60 - velA) * 0.06;
      velB += (db * 60 - velB) * 0.06;
      if (!grabbing) { velA *= 0.95; velB *= 0.95; }
      gl.uniform1f(uT, zt);
      gl.uniform2f(uR, canvas.width, canvas.height * 1.92);
      gl.uniform2f(uCubeOff, smoothA, smoothB);
      gl.uniform2f(uCubeVel, velA, velB);
      gl.uniform1f(uCloudQ, cloudQ);
      if (darkCur !== darkLast) { darkLast = darkCur; gl.clearColor(darkCur ? 23/255 : 0, darkCur ? 23/255 : 0, darkCur ? 23/255 : 0, darkCur ? 1 : 0); }
      gl.uniform1f(uDark, darkCur);
      gl.uniform1f(uIntro, Math.min(1.0, (zt - ir) / 2.0));
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      if (!mounted) { mounted = true; boot.markPhase("sea_first_frame", 38); boot.markPhase("sea_full_first_frame", 100); boot.markSea(); }
      raf = requestAnimationFrame(draw);
    }
    raf = requestAnimationFrame(draw);

    var io = new IntersectionObserver(function (entries) {
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].isIntersecting) { if (!running) { running = true; t0 = performance.now(); raf = requestAnimationFrame(draw); } }
        else { running = false; cancelAnimationFrame(raf); }
      }
    }, { threshold: 0, rootMargin: "120px" });
    io.observe(canvas);
    if (reduceMotion) { running = false; cancelAnimationFrame(raf); }
  }

  // ======================================================================
  // 6. Self-init
  // ======================================================================

  function init() {
    startBootAnim();
    if (!WEBGL) {
      var c = document.querySelectorAll("[data-cube-logo-host], #sea-canvas");
      for (var i = 0; i < c.length; i++) c[i].setAttribute("data-gfx-failed", "1");
      var sea = document.getElementById("sea-canvas");
      if (sea) sea.setAttribute("data-sea-footer-error", "1");
      boot.markSea(); boot.markLogo();
      return;
    }
    var cubes = document.querySelectorAll("[data-cube-logo-host]");
    if (cubes.length === 0) boot.markLogo();
    for (var i = 0; i < cubes.length; i++) mountCube(cubes[i]);
    var sea = document.getElementById("sea-canvas");
    if (sea) mountSea(sea);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
