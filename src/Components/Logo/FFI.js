function compileShader(gl, type, source) {
  const sh = gl.createShader(type);
  gl.shaderSource(sh, source);
  gl.compileShader(sh);
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    console.warn("Logo shader compile:", gl.getShaderInfoLog(sh));
    gl.deleteShader(sh);
    return null;
  }
  return sh;
}

function createProgram(gl, vsSource, fsSource) {
  const vs = compileShader(gl, gl.VERTEX_SHADER, vsSource);
  const fs = compileShader(gl, gl.FRAGMENT_SHADER, fsSource);
  if (!vs || !fs) return null;
  const prog = gl.createProgram();
  gl.attachShader(prog, vs);
  gl.attachShader(prog, fs);
  gl.linkProgram(prog);
  gl.deleteShader(vs);
  gl.deleteShader(fs);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
    console.warn("Logo program link:", gl.getProgramInfoLog(prog));
    gl.deleteProgram(prog);
    return null;
  }
  return prog;
}

export function logoInitImpl(canvas, vertexShader, fragmentShader, pos, norm, idx) {
  if (!canvas) {
    return null;
  }

  const styleW = 60;
  const styleH = 60;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(styleW * dpr);
  canvas.height = Math.round(styleH * dpr);

  const gl = canvas.getContext("webgl", { alpha: true, antialias: true, premultipliedAlpha: false });
  if (!gl) {
    console.warn("Logo: WebGL unavailable");
    return null;
  }
  gl.viewport(0, 0, canvas.width, canvas.height);

  const prog = createProgram(gl, vertexShader, fragmentShader);
  if (!prog) return null;

  const posBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, posBuf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(pos), gl.STATIC_DRAW);

  const normBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, normBuf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(norm), gl.STATIC_DRAW);

  const idxBuf = gl.createBuffer();
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, idxBuf);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(idx), gl.STATIC_DRAW);

  const indexCount = idx.length;

  return {
    gl,
    prog,
    canvas,
    posBuf,
    normBuf,
    idxBuf,
    indexCount,
    aPosition: gl.getAttribLocation(prog, "aPosition"),
    aNormal: gl.getAttribLocation(prog, "aNormal"),
    aTexCoord: gl.getAttribLocation(prog, "aTexCoord"),
    uProjectionMatrix: gl.getUniformLocation(prog, "uProjectionMatrix"),
    uModelViewMatrix: gl.getUniformLocation(prog, "uModelViewMatrix"),
    uColorLight: gl.getUniformLocation(prog, "uColorLight"),
    uColorDark: gl.getUniformLocation(prog, "uColorDark"),
    uLightPosition: gl.getUniformLocation(prog, "uLightPosition"),
    uResolution: gl.getUniformLocation(prog, "uResolution"),
    uTexture: gl.getUniformLocation(prog, "uTexture"),
  };
}

export function logoBufferAspectImpl(h) {
  return h.canvas.width / h.canvas.height;
}

// Called once after init — sets projection, light, colors, static GL state, and binds attributes.
export function logoSetupSceneImpl(handle, projCol, lx, ly, lz) {
  const { gl, prog, canvas, posBuf, normBuf, idxBuf } = handle;

  gl.useProgram(prog);

  gl.enable(gl.DEPTH_TEST);
  gl.depthFunc(gl.LEQUAL);
  gl.disable(gl.CULL_FACE);
  gl.clearColor(0, 0, 0, 0);

  gl.uniformMatrix4fv(handle.uProjectionMatrix, false, new Float32Array(projCol));
  gl.uniform3f(handle.uColorLight, 234 / 255, 88 / 255, 12 / 255);
  gl.uniform3f(handle.uColorDark, 0, 0, 0);
  gl.uniform3f(handle.uLightPosition, lx, ly, lz);
  gl.uniform2f(handle.uResolution, canvas.width, canvas.height);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, idxBuf);

  gl.bindBuffer(gl.ARRAY_BUFFER, posBuf);
  gl.enableVertexAttribArray(handle.aPosition);
  gl.vertexAttribPointer(handle.aPosition, 3, gl.FLOAT, false, 0, 0);

  gl.bindBuffer(gl.ARRAY_BUFFER, normBuf);
  gl.enableVertexAttribArray(handle.aNormal);
  gl.vertexAttribPointer(handle.aNormal, 3, gl.FLOAT, false, 0, 0);

  handle._mvBuf = new Float32Array(16);
}

export function logoDrawImpl(handle, mvCol) {
  const { gl, indexCount } = handle;
  handle._mvBuf.set(mvCol);
  gl.uniformMatrix4fv(handle.uModelViewMatrix, false, handle._mvBuf);
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  gl.drawElements(gl.TRIANGLES, indexCount, gl.UNSIGNED_SHORT, 0);
}

export function logoSetupTextureImpl(handle, imageSrc, light, dark) {
  const { gl, prog, canvas, posBuf, normBuf, idxBuf } = handle;
  gl.useProgram(prog);
  gl.disable(gl.DEPTH_TEST);
  gl.disable(gl.CULL_FACE);
  gl.clearColor(0, 0, 0, 0);
  gl.uniform3f(handle.uColorLight, light, light, light);
  gl.uniform3f(handle.uColorDark, dark, dark, dark);
  gl.uniform2f(handle.uResolution, canvas.width, canvas.height);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, idxBuf);

  gl.bindBuffer(gl.ARRAY_BUFFER, posBuf);
  gl.enableVertexAttribArray(handle.aPosition);
  gl.vertexAttribPointer(handle.aPosition, 2, gl.FLOAT, false, 0, 0);

  gl.bindBuffer(gl.ARRAY_BUFFER, normBuf);
  gl.enableVertexAttribArray(handle.aTexCoord);
  gl.vertexAttribPointer(handle.aTexCoord, 2, gl.FLOAT, false, 0, 0);

  const tex = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texImage2D(
    gl.TEXTURE_2D,
    0,
    gl.RGBA,
    1,
    1,
    0,
    gl.RGBA,
    gl.UNSIGNED_BYTE,
    new Uint8Array([0, 0, 0, 255]),
  );
  gl.uniform1i(handle.uTexture, 0);
  handle._textureReady = false;

  const img = new Image();
  img.crossOrigin = "anonymous";
  img.onload = () => {
    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
    handle._textureReady = true;
    logoDraw2DImpl(handle);
  };
  img.src = imageSrc;
}

export function logoDraw2DImpl(handle) {
  const { gl, indexCount } = handle;
  if (!handle._textureReady) return;
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.drawElements(gl.TRIANGLES, indexCount, gl.UNSIGNED_SHORT, 0);
}

export function performanceNowMillis() {
  return performance.now();
}

export function rafImpl(eff) {
  requestAnimationFrame(function () {
    eff();
  });
}
