/** Same ordering as Logo/FFI and Main.js sea: wait COMPLETION_STATUS_KHR before LINK_STATUS. */
function createLinkedProgram(gl, vsSource, fsSource) {
  const ext = gl.getExtension("KHR_parallel_shader_compile");

  const compile = (type, source) => {
    const sh = gl.createShader(type);
    gl.shaderSource(sh, source);
    gl.compileShader(sh);
    if (ext) gl.getShaderParameter(sh, ext.COMPLETION_STATUS_KHR);
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
      console.warn("Banner shader compile:", gl.getShaderInfoLog(sh));
      gl.deleteShader(sh);
      return null;
    }
    return sh;
  };

  const vs = compile(gl.VERTEX_SHADER, vsSource);
  const fs = compile(gl.FRAGMENT_SHADER, fsSource);
  if (!vs || !fs) return null;

  const program = gl.createProgram();
  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);

  if (ext) gl.getProgramParameter(program, ext.COMPLETION_STATUS_KHR);

  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.warn("Banner program link:", gl.getProgramInfoLog(program));
    gl.deleteProgram(program);
    gl.deleteShader(vs);
    gl.deleteShader(fs);
    return null;
  }

  gl.deleteShader(vs);
  gl.deleteShader(fs);
  return program;
}

function parseHexColor(hex) {
  const n = parseInt(hex.replace("#", ""), 16);
  return [
    ((n >> 16) & 0xff) / 255,
    ((n >> 8) & 0xff) / 255,
    (n & 0xff) / 255,
  ];
}

function resizeToDisplaySize(handle) {
  const rect = handle.canvas.getBoundingClientRect();
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const width = Math.max(1, Math.round(rect.width * dpr));
  const height = Math.max(1, Math.round(rect.height * dpr));
  if (handle.canvas.width !== width || handle.canvas.height !== height) {
    handle.canvas.width = width;
    handle.canvas.height = height;
  }
  handle.gl.viewport(0, 0, width, height);
}

function updateContainGeometry(handle) {
  const { image, canvas } = handle;
  if (!image || image.naturalWidth <= 0 || image.naturalHeight <= 0) return;

  const canvasAspect = canvas.width / canvas.height;
  const imageAspect = image.naturalWidth / image.naturalHeight;
  let sx = 1.0;
  let sy = 1.0;

  if (imageAspect > canvasAspect) {
    sy = canvasAspect / imageAspect;
  } else {
    sx = imageAspect / canvasAspect;
  }

  const pos = new Float32Array([
    -sx, -sy,
     sx, -sy,
     sx,  sy,
    -sx,  sy,
  ]);
  handle.gl.bindBuffer(handle.gl.ARRAY_BUFFER, handle.positionBuffer);
  handle.gl.bufferData(handle.gl.ARRAY_BUFFER, pos, handle.gl.STATIC_DRAW);
}

function draw(handle) {
  const { gl, image } = handle;
  resizeToDisplaySize(handle);
  gl.useProgram(handle.program);
  gl.uniform2f(handle.uResolution, handle.canvas.width, handle.canvas.height);
  gl.uniform3f(handle.uColorLight, handle.colorLight[0], handle.colorLight[1], handle.colorLight[2]);
  gl.uniform3f(handle.uColorDark, handle.colorDark[0], handle.colorDark[1], handle.colorDark[2]);
  gl.clear(gl.COLOR_BUFFER_BIT);
  if (!image || !handle.textureReady) return;
  updateContainGeometry(handle);
  gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, 0);
}

export function initBannerImpl(canvas, vertexShader, fragmentShader) {
  if (!canvas) return null;
  const gl = canvas.getContext("webgl", {
    alpha: true,
    antialias: true,
    premultipliedAlpha: false,
  });
  if (!gl) {
    console.warn("Banner: WebGL unavailable");
    return null;
  }

  const program = createLinkedProgram(gl, vertexShader, fragmentShader);
  if (!program) return null;

  const handle = {
    canvas,
    gl,
    program,
    image: null,
    ro: null,
    textureReady: false,
    colorLight: [0.96, 0.96, 0.96],
    colorDark: [1.0, 0.294, 0.149],
    aPosition: gl.getAttribLocation(program, "aPosition"),
    aTexCoord: gl.getAttribLocation(program, "aTexCoord"),
    uTexture: gl.getUniformLocation(program, "uTexture"),
    uColorLight: gl.getUniformLocation(program, "uColorLight"),
    uColorDark: gl.getUniformLocation(program, "uColorDark"),
    uResolution: gl.getUniformLocation(program, "uResolution"),
    positionBuffer: gl.createBuffer(),
    texCoordBuffer: gl.createBuffer(),
    indexBuffer: gl.createBuffer(),
    texture: gl.createTexture(),
  };

  gl.useProgram(program);
  gl.disable(gl.DEPTH_TEST);
  gl.disable(gl.CULL_FACE);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.clearColor(0.0, 0.0, 0.0, 0.0);

  gl.bindBuffer(gl.ARRAY_BUFFER, handle.positionBuffer);
  gl.enableVertexAttribArray(handle.aPosition);
  gl.vertexAttribPointer(handle.aPosition, 2, gl.FLOAT, false, 0, 0);

  gl.bindBuffer(gl.ARRAY_BUFFER, handle.texCoordBuffer);
  gl.bufferData(
    gl.ARRAY_BUFFER,
    new Float32Array([
      0, 0,
      1, 0,
      1, 1,
      0, 1,
    ]),
    gl.STATIC_DRAW
  );
  gl.enableVertexAttribArray(handle.aTexCoord);
  gl.vertexAttribPointer(handle.aTexCoord, 2, gl.FLOAT, false, 0, 0);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, handle.indexBuffer);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array([0, 1, 2, 0, 2, 3]), gl.STATIC_DRAW);

  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, handle.texture);
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
    new Uint8Array([255, 255, 255, 255])
  );
  gl.uniform1i(handle.uTexture, 0);

  handle.ro = new ResizeObserver(() => {
    draw(handle);
  });
  handle.ro.observe(canvas);
  resizeToDisplaySize(handle);
  draw(handle);

  return handle;
}

export function setBannerImageImpl(handle, src, colorLight, colorDark) {
  if (!handle) return;
  handle.colorLight = parseHexColor(colorLight);
  handle.colorDark = parseHexColor(colorDark);
  handle.gl.clearColor(0.0, 0.0, 0.0, 0.0);

  const image = new Image();
  image.crossOrigin = "anonymous";
  handle.image = image;
  handle.textureReady = false;
  draw(handle);

  image.onload = () => {
    if (handle.image !== image) return;
    const { gl, texture } = handle;
    gl.useProgram(handle.program);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    handle.textureReady = true;
    draw(handle);
  };

  image.onerror = () => {
    if (handle.image !== image) return;
    handle.textureReady = false;
  };

  image.src = src;
}

export function disposeBannerImpl(handle) {
  if (!handle) return;
  handle.image = null;
  handle.textureReady = false;
  if (handle.ro) handle.ro.disconnect();
}
