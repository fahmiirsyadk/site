import vertexSource from './dithered-image.vert?raw'
import fragmentSource from './dithered-image.frag?raw'
import {
  bayerMatrix,
  ditherColor,
  ditherLayout,
  quadVertices,
  shouldDrawFrame,
} from 'purescript/Runtime.Dither/index.ts'

import { createShaderProgram, deleteShaderProgram, noop, releaseContext } from './webgl.ts'

const mount = (root: HTMLElement): (() => void) => {
  const image = root.querySelector('img[data-dithered-source]')
  const canvas = root.querySelector('canvas[data-dithered-canvas]')
  if (!(image instanceof HTMLImageElement) || !(canvas instanceof HTMLCanvasElement)) return noop

  const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: false })
  if (gl === null) {
    root.dataset.ditherFallback = 'true'
    return noop
  }

  const shaderProgram = createShaderProgram(gl, vertexSource, fragmentSource, 'dithered-image')
  if (shaderProgram === undefined) {
    root.dataset.ditherFallback = 'true'
    releaseContext(gl)
    return noop
  }

  const { program } = shaderProgram
  const texture = gl.createTexture()
  const bayerTexture = gl.createTexture()
  const positionBuffer = gl.createBuffer()
  const textureBuffer = gl.createBuffer()
  if (texture === null || bayerTexture === null || positionBuffer === null || textureBuffer === null) {
    if (texture !== null) gl.deleteTexture(texture)
    if (bayerTexture !== null) gl.deleteTexture(bayerTexture)
    if (positionBuffer !== null) gl.deleteBuffer(positionBuffer)
    if (textureBuffer !== null) gl.deleteBuffer(textureBuffer)
    deleteShaderProgram(gl, shaderProgram)
    releaseContext(gl)
    root.dataset.ditherFallback = 'true'
    return noop
  }
  const deleteGraphics = (): void => {
    gl.deleteTexture(texture)
    gl.deleteTexture(bayerTexture)
    gl.deleteBuffer(positionBuffer)
    gl.deleteBuffer(textureBuffer)
    deleteShaderProgram(gl, shaderProgram)
  }

  const position = gl.getAttribLocation(program, 'a_position')
  const textureCoordinate = gl.getAttribLocation(program, 'a_texCoord')
  if (position < 0 || textureCoordinate < 0) {
    deleteGraphics()
    releaseContext(gl)
    root.dataset.ditherFallback = 'true'
    return noop
  }

  const resolution = gl.getUniformLocation(program, 'u_resolution')
  const time = gl.getUniformLocation(program, 'u_time')
  const ink = gl.getUniformLocation(program, 'u_ink')
  let frame = 0
  let disposed = false
  let lastFrame = 0
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  gl.useProgram(program)
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(quadVertices), gl.STATIC_DRAW)
  gl.enableVertexAttribArray(position)
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0)
  gl.bindBuffer(gl.ARRAY_BUFFER, textureBuffer)
  gl.enableVertexAttribArray(textureCoordinate)
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
  gl.activeTexture(gl.TEXTURE1)
  gl.bindTexture(gl.TEXTURE_2D, bayerTexture)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, 4, 4, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, new Uint8Array(bayerMatrix))
  gl.uniform1i(gl.getUniformLocation(program, 'u_bayer'), 1)
  gl.activeTexture(gl.TEXTURE0)
  gl.bindTexture(gl.TEXTURE_2D, texture)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.uniform1i(gl.getUniformLocation(program, 'u_image'), 0)

  const resize = (): void => {
    const bounds = root.getBoundingClientRect()
    if (bounds.width === 0 || bounds.height === 0) return
    const layout = ditherLayout({
      width: bounds.width,
      height: bounds.height,
      devicePixelRatio: window.devicePixelRatio,
      sourceWidth: image.naturalWidth,
      sourceHeight: image.naturalHeight,
    })
    canvas.width = layout.canvasWidth
    canvas.height = layout.canvasHeight
    canvas.style.width = `${layout.cssWidth}px`
    canvas.style.height = `${layout.cssHeight}px`
    gl.viewport(0, 0, canvas.width, canvas.height)
    gl.uniform2f(resolution, canvas.width, canvas.height)
    gl.bindBuffer(gl.ARRAY_BUFFER, textureBuffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(layout.textureCoordinates), gl.STATIC_DRAW)
    gl.vertexAttribPointer(textureCoordinate, 2, gl.FLOAT, false, 0, 0)
  }

  const render = (timestamp: number): void => {
    if (disposed || image.naturalWidth === 0) return
    if (!shouldDrawFrame({ reduceMotion, timestamp, previousTimestamp: lastFrame })) {
      frame = requestAnimationFrame(render)
      return
    }
    lastFrame = timestamp
    gl.useProgram(program)
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.uniform1f(time, timestamp / 1000)
    const color = ditherColor(getComputedStyle(root).getPropertyValue('--dither-ink'))
    gl.uniform3f(ink, color.red, color.green, color.blue)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    if (!reduceMotion) frame = requestAnimationFrame(render)
  }

  const load = (): void => {
    if (image.naturalWidth === 0 || image.naturalHeight === 0) return
    if (root.getBoundingClientRect().height === 0) root.style.aspectRatio = `${image.naturalWidth} / ${image.naturalHeight}`
    canvas.style.aspectRatio = `${image.naturalWidth} / ${image.naturalHeight}`
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image)
    resize()
    cancelAnimationFrame(frame)
    frame = requestAnimationFrame(render)
  }

  const resizeObserver = new ResizeObserver(resize)
  const themeObserver = new MutationObserver(() => render(performance.now()))
  // Other canvases on the page also hold contexts, and browsers cap how many
  // can be live. If this one is dropped, show the plain image rather than an
  // empty box.
  const handleContextLost = (): void => {
    disposed = true
    cancelAnimationFrame(frame)
    root.dataset.ditherFallback = 'true'
  }
  canvas.addEventListener('webglcontextlost', handleContextLost)
  resizeObserver.observe(root)
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
  image.addEventListener('load', load)
  if (image.complete) load()

  return () => {
    disposed = true
    cancelAnimationFrame(frame)
    resizeObserver.disconnect()
    themeObserver.disconnect()
    image.removeEventListener('load', load)
    canvas.removeEventListener('webglcontextlost', handleContextLost)
    deleteGraphics()
    // Deleting resources does not free the context, and every navigation
    // creates a fresh one per image. Release it so the page stays under the
    // browser's live-context cap.
    releaseContext(gl)
  }
}

const mountOne = (root: HTMLElement): (() => void) => {
  if (root.dataset.ditherInitialized === 'true') return noop
  root.dataset.ditherInitialized = 'true'
  const dispose = mount(root)
  return () => {
    delete root.dataset.ditherInitialized
    delete root.dataset.ditherFallback
    dispose()
  }
}

const ditheredImagesIn = (node: Node): HTMLElement[] => {
  if (!(node instanceof HTMLElement)) return []
  const self = node.matches('[data-dithered-image]') ? [node] : []
  return [...self, ...Array.from(node.querySelectorAll<HTMLElement>('[data-dithered-image]'))]
}

export const mountDitheredImage = (element: Element): (() => void) => {
  if (!(element instanceof HTMLElement)) return noop
  if (element.matches('[data-dithered-image]')) return mountOne(element)

  const mounted = new Map<HTMLElement, () => void>()
  const add = (root: HTMLElement): void => {
    if (mounted.has(root)) return
    mounted.set(root, mountOne(root))
  }
  const remove = (root: HTMLElement): void => {
    const dispose = mounted.get(root)
    if (dispose === undefined) return
    mounted.delete(root)
    dispose()
  }

  ditheredImagesIn(element).forEach(add)

  // Client-side navigation replaces this container's innerHTML in place, which
  // swaps in fresh unmounted canvases without re-firing the framework's mount
  // hook. Watch the subtree so those get mounted and the detached ones released.
  const contentObserver = new MutationObserver(records => {
    for (const record of records) {
      record.removedNodes.forEach(node => ditheredImagesIn(node).forEach(remove))
      record.addedNodes.forEach(node => ditheredImagesIn(node).forEach(add))
    }
  })
  contentObserver.observe(element, { childList: true, subtree: true })

  return () => {
    contentObserver.disconnect()
    Array.from(mounted.keys()).forEach(remove)
  }
}
