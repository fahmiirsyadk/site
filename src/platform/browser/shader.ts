import fragmentShader from './sea-footer.frag?raw'
import { rasterLayout } from 'purescript/Runtime.Canvas/index.ts'
import { frameTiming } from 'purescript/Runtime.Frame/index.ts'
import {
  initialSeaMotion,
  retargetSeaMotion,
  seaDragTarget,
  stepSeaMotion,
} from 'purescript/Runtime.SeaMotion/index.ts'

import vertexShader from './sea-footer.vert?raw'

import { createShaderProgram, deleteShaderProgram, noop, releaseContext } from './webgl.ts'

export const mountSeaShader = (element: Element): (() => void) => {
  if (!(element instanceof HTMLCanvasElement) || element.dataset.initialized === 'true') return noop
  const canvas = element
  const gl = canvas.getContext('webgl2', {
    alpha: true,
    premultipliedAlpha: false,
    antialias: false,
    depth: false,
    stencil: false,
  })
  if (gl === null) return noop
  const shaderProgram = createShaderProgram(gl, vertexShader, fragmentShader, 'sea-footer')
  if (shaderProgram === undefined) {
    releaseContext(gl)
    return noop
  }
  const { program } = shaderProgram
  const vertexArray = gl.createVertexArray()
  if (vertexArray === null) {
    deleteShaderProgram(gl, shaderProgram)
    releaseContext(gl)
    return noop
  }
  gl.useProgram(program)
  gl.bindVertexArray(vertexArray)
  const time = gl.getUniformLocation(program, 't')
  const resolution = gl.getUniformLocation(program, 'r')
  const cubeOffset = gl.getUniformLocation(program, 'cubeOff')
  const cubeVelocity = gl.getUniformLocation(program, 'cubeVel')
  const cloudQuality = gl.getUniformLocation(program, 'cloudQ')
  const dark = gl.getUniformLocation(program, 'uiDark')
  const intro = gl.getUniformLocation(program, 'seaIntro')
  const ditherPixelSize = gl.getUniformLocation(program, 'ditherPx')
  const labHoverUniform = gl.getUniformLocation(program, 'labHover')
  let dragging = false
  let startX = 0
  let startY = 0
  let baseX = 0
  let baseY = 0
  let motion = initialSeaMotion
  const pointerDown = (event: PointerEvent): void => {
    dragging = true
    startX = event.clientX
    startY = event.clientY
    baseX = motion.targetX
    baseY = motion.targetY
    canvas.setPointerCapture(event.pointerId)
    event.preventDefault()
  }
  const pointerMove = (event: PointerEvent): void => {
    if (!dragging) return
    motion = retargetSeaMotion(seaDragTarget({
      baseX,
      baseY,
      startX,
      startY,
      currentX: event.clientX,
      currentY: event.clientY,
      width: canvas.clientWidth,
      height: canvas.clientHeight,
    }), motion)
  }
  const endDrag = (): void => {
    dragging = false
  }
  canvas.addEventListener('pointerdown', pointerDown)
  canvas.addEventListener('pointermove', pointerMove)
  canvas.addEventListener('pointerup', endDrag)
  canvas.addEventListener('pointercancel', endDrag)
  const resize = (): void => {
    const bounds = canvas.getBoundingClientRect()
    const layout = rasterLayout({
      width: bounds.width,
      height: bounds.height,
      devicePixelRatio: window.devicePixelRatio,
      minimumPixelRatio: 1,
      maximumPixelRatio: 2,
    })
    canvas.width = layout.canvasWidth
    canvas.height = layout.canvasHeight
    gl.viewport(0, 0, canvas.width, canvas.height)
    gl.uniform1f(ditherPixelSize, layout.pixelRatio)
  }
  resize()
  const resizeObserver = new ResizeObserver(resize)
  resizeObserver.observe(canvas)
  canvas.dataset.initialized = 'true'
  const startedAt = performance.now()
  motion = { ...motion, labHover: canvas.parentElement?.dataset.labInteraction === 'hovered' ? 1 : 0 }
  let previousFrameTime = startedAt
  let running = true
  let disposed = false
  let animationFrame = 0
  const render = (timestamp: number): void => {
    if (!running || disposed) return
    const timing = frameTiming({ timestamp, previousTimestamp: previousFrameTime, startedAt })
    previousFrameTime = timestamp
    const labHoverTarget = canvas.parentElement?.dataset.labInteraction === 'hovered' ? 1 : 0
    motion = stepSeaMotion({ dragging, frameDuration: timing.frameDuration, labHoverTarget }, motion)
    gl.uniform1f(time, timing.seconds)
    gl.uniform2f(resolution, canvas.width, canvas.height * 1.92)
    gl.uniform2f(cubeOffset, motion.smoothX, motion.smoothY)
    gl.uniform2f(cubeVelocity, motion.velocityX, motion.velocityY)
    gl.uniform1f(cloudQuality, 0.6)
    gl.uniform1f(dark, document.documentElement.classList.contains('dark') ? 1 : 0)
    gl.uniform1f(intro, timing.intro)
    gl.uniform1f(labHoverUniform, motion.labHover)
    gl.clearColor(0, 0, 0, 0)
    gl.clear(gl.COLOR_BUFFER_BIT)
    gl.drawArrays(gl.TRIANGLES, 0, 3)
    animationFrame = requestAnimationFrame(render)
  }
  const visibility = new IntersectionObserver(
    entries => {
      const entry = entries[0]
      if (entry === undefined || disposed) return
      if (entry.isIntersecting) {
        if (!running) {
          running = true
          animationFrame = requestAnimationFrame(render)
        }
      } else {
        running = false
        cancelAnimationFrame(animationFrame)
      }
    },
    { rootMargin: '120px' },
  )
  visibility.observe(canvas)
  animationFrame = requestAnimationFrame(render)
  return () => {
    disposed = true
    running = false
    cancelAnimationFrame(animationFrame)
    visibility.disconnect()
    resizeObserver.disconnect()
    canvas.removeEventListener('pointerdown', pointerDown)
    canvas.removeEventListener('pointermove', pointerMove)
    canvas.removeEventListener('pointerup', endDrag)
    canvas.removeEventListener('pointercancel', endDrag)
    gl.deleteVertexArray(vertexArray)
    deleteShaderProgram(gl, shaderProgram)
    releaseContext(gl)
    delete canvas.dataset.initialized
  }
}
