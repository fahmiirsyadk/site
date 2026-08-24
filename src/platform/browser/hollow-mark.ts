import {
  beginHollowDrag,
  dragHollow,
  endHollowDrag,
  hollowCubeRotation,
  hollowDragValues,
  initialHollowMotion,
  initialHollowVisual,
  stepHollowVisual,
  stepHollowMotion,
} from 'purescript/Runtime.HollowMotion/index.ts'
import { frameTiming } from 'purescript/Runtime.Frame/index.ts'
import {
  hollowVertexCount,
  hollowVertices,
} from 'purescript/Runtime.HollowGeometry/index.ts'
import { rasterLayout } from 'purescript/Runtime.Canvas/index.ts'

import vertexSource from './hollow-mark.vert?raw'
import fragmentSource from './hollow-mark.frag?raw'

import { createShaderProgram, deleteShaderProgram, noop, releaseContext } from './webgl.ts'

export const mountHollowMark = (element: Element): (() => void) => {
  if (!(element instanceof HTMLCanvasElement)) return noop
  const gl = element.getContext('webgl', {
    alpha: true,
    antialias: true,
    depth: true,
    premultipliedAlpha: true,
  })
  if (gl === null) return noop
  const shaderProgram = createShaderProgram(gl, vertexSource, fragmentSource, 'hollow-mark')
  if (shaderProgram === undefined) {
    releaseContext(gl)
    return noop
  }
  const { program } = shaderProgram
  const buffer = gl.createBuffer()
  const moonTexture = gl.createTexture()
  if (buffer === null || moonTexture === null) {
    if (buffer !== null) gl.deleteBuffer(buffer)
    if (moonTexture !== null) gl.deleteTexture(moonTexture)
    deleteShaderProgram(gl, shaderProgram)
    releaseContext(gl)
    return noop
  }

  const vertices = new Float32Array(hollowVertices)
  const stride = 7 * Float32Array.BYTES_PER_ELEMENT
  const position = gl.getAttribLocation(program, 'a_position')
  const surfaceNormal = gl.getAttribLocation(program, 'a_normal')
  const region = gl.getAttribLocation(program, 'a_region')
  const angle = gl.getUniformLocation(program, 'u_angle')
  const cubeAngle = gl.getUniformLocation(program, 'u_cube_angle')
  const aspect = gl.getUniformLocation(program, 'u_aspect')
  const time = gl.getUniformLocation(program, 'u_time')
  const labHoverUniform = gl.getUniformLocation(program, 'u_lab_hover')
  const moonTextureUniform = gl.getUniformLocation(program, 'u_moon_texture')

  gl.useProgram(program)
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW)
  gl.enableVertexAttribArray(position)
  gl.vertexAttribPointer(position, 3, gl.FLOAT, false, stride, 0)
  gl.enableVertexAttribArray(surfaceNormal)
  gl.vertexAttribPointer(surfaceNormal, 3, gl.FLOAT, false, stride, 3 * Float32Array.BYTES_PER_ELEMENT)
  gl.enableVertexAttribArray(region)
  gl.vertexAttribPointer(region, 1, gl.FLOAT, false, stride, 6 * Float32Array.BYTES_PER_ELEMENT)
  gl.enable(gl.DEPTH_TEST)
  gl.depthFunc(gl.LEQUAL)
  gl.disable(gl.CULL_FACE)
  let disposed = false
  gl.activeTexture(gl.TEXTURE2)
  gl.bindTexture(gl.TEXTURE_2D, moonTexture)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
  gl.texImage2D(
    gl.TEXTURE_2D,
    0,
    gl.RGBA,
    1,
    1,
    0,
    gl.RGBA,
    gl.UNSIGNED_BYTE,
    new Uint8Array([255, 255, 255, 255]),
  )
  gl.uniform1i(moonTextureUniform, 2)
  const moonImage = new Image()
  moonImage.decoding = 'async'
  const uploadMoonTexture = (): void => {
    if (disposed || moonImage.naturalWidth === 0) return
    gl.activeTexture(gl.TEXTURE2)
    gl.bindTexture(gl.TEXTURE_2D, moonTexture)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, moonImage)
  }
  moonImage.addEventListener('load', uploadMoonTexture)
  moonImage.src = '/assets/images/lroc-color-1k.webp'

  let animationFrame = 0
  const startedAt = performance.now()
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  let dragging = false
  let dragStartX = 0
  let dragStartAngle = 0
  let motion = initialHollowMotion
  let visual = initialHollowVisual(element.dataset.labInteraction === 'hovered' ? 1 : 0)
  let previousPointerX = 0
  let previousPointerTime = 0
  let previousFrameTime = performance.now()
  const pointerDown = (event: PointerEvent): void => {
    dragging = true
    dragStartX = event.clientX
    dragStartAngle = motion.targetAngle
    previousPointerX = event.clientX
    previousPointerTime = performance.now()
    motion = beginHollowDrag(motion)
    element.dataset.dragging = 'true'
    element.setPointerCapture(event.pointerId)
    event.preventDefault()
  }
  const pointerMove = (event: PointerEvent): void => {
    if (!dragging) return
    const now = performance.now()
    motion = dragHollow(hollowDragValues({
      dragStartAngle,
      dragStartX,
      currentX: event.clientX,
      previousX: previousPointerX,
      width: element.clientWidth,
      elapsed: now - previousPointerTime,
    }), motion)
    previousPointerX = event.clientX
    previousPointerTime = now
  }
  const pointerUp = (): void => {
    motion = endHollowDrag({ stale: performance.now() - previousPointerTime > 80 }, motion)
    dragging = false
    delete element.dataset.dragging
  }
  element.addEventListener('pointerdown', pointerDown)
  element.addEventListener('pointermove', pointerMove)
  element.addEventListener('pointerup', pointerUp)
  element.addEventListener('pointercancel', pointerUp)
  const resize = (): void => {
    const bounds = element.getBoundingClientRect()
    if (bounds.width === 0 || bounds.height === 0) return
    const layout = rasterLayout({
      width: bounds.width,
      height: bounds.height,
      devicePixelRatio: window.devicePixelRatio,
      minimumPixelRatio: 1,
      maximumPixelRatio: 6,
    })
    element.width = layout.canvasWidth
    element.height = layout.canvasHeight
    gl.viewport(0, 0, element.width, element.height)
  }
  const render = (timestamp: number): void => {
    if (disposed) return
    const timing = frameTiming({ timestamp, previousTimestamp: previousFrameTime, startedAt })
    const cubeRotation = hollowCubeRotation({ reduceMotion, elapsed: timing.seconds })
    previousFrameTime = timestamp
    const labHoverTarget = element.dataset.labInteraction === 'hovered' ? 1 : 0
    motion = stepHollowMotion({ dragging, frameDuration: timing.frameDuration, reduceMotion }, motion)
    visual = stepHollowVisual({
      frameDuration: timing.frameDuration,
      labHoverTarget,
      interactionActive: motion.interactionActive,
      reduceMotion,
    }, visual)
    gl.clearColor(0, 0, 0, 0)
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    gl.uniform1f(angle, motion.smoothAngle)
    gl.uniform1f(cubeAngle, cubeRotation)
    gl.uniform1f(aspect, element.width / element.height)
    gl.uniform1f(time, reduceMotion ? 0 : visual.motionSeconds)
    gl.uniform1f(labHoverUniform, visual.labHover)
    gl.drawArrays(gl.TRIANGLES, 0, hollowVertexCount)
    animationFrame = requestAnimationFrame(render)
  }

  const resizeObserver = new ResizeObserver(() => {
    resize()
    if (reduceMotion) render(performance.now())
  })
  const themeObserver = new MutationObserver(() => render(performance.now()))
  resizeObserver.observe(element)
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
  window.addEventListener('resize', resize)
  resize()
  animationFrame = requestAnimationFrame(render)

  return () => {
    disposed = true
    cancelAnimationFrame(animationFrame)
    resizeObserver.disconnect()
    themeObserver.disconnect()
    window.removeEventListener('resize', resize)
    element.removeEventListener('pointerdown', pointerDown)
    element.removeEventListener('pointermove', pointerMove)
    element.removeEventListener('pointerup', pointerUp)
    element.removeEventListener('pointercancel', pointerUp)
    gl.deleteBuffer(buffer)
    moonImage.removeEventListener('load', uploadMoonTexture)
    gl.deleteTexture(moonTexture)
    deleteShaderProgram(gl, shaderProgram)
    releaseContext(gl)
  }
}
