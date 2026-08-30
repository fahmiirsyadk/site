// WebGL mechanics for a dithered image. PureScript (DitheredImage.purs) owns
// every decision — when to draw, which ink color, how the canvas is laid out.
// This sibling only executes WebGL calls, in the same order the pre-migration
// mount used. The program stays bound and the image texture stays on TEXTURE0
// for the context's whole lifetime, so the draw path skips the per-frame
// useProgram/bindTexture the original paid.
import { Effect } from 'effect'

import { createShaderProgram, deleteShaderProgram, releaseContext, type GlContext, type ShaderProgram } from './Gl.ts'

import { ditheredImageShaders } from './Shaders.ts'

type Cleanup = () => void
export type DitherLayout = Readonly<{
  canvasWidth: number
  canvasHeight: number
  cssWidth: number
  cssHeight: number
  textureCoordinates: ReadonlyArray<number>
}>

export type DitherUniforms = Readonly<{
  time: number
  red: number
  green: number
  blue: number
}>

export type PreparedDitherImage = Readonly<{
  canvas: HTMLCanvasElement
  gl: GlContext
  program: ShaderProgram
  imageTexture: WebGLTexture
  bayerTexture: WebGLTexture
  positionBuffer: WebGLBuffer
  textureBuffer: WebGLBuffer
  textureCoordinate: number
  uniforms: Readonly<{
    resolution: WebGLUniformLocation | null
    time: WebGLUniformLocation | null
    ink: WebGLUniformLocation | null
  }>
}>

// Yields zero handles when the element is not a canvas, WebGL is missing, the
// shaders fail, or the attribute locations are absent — the PureScript side
// then raises the fallback flag and mounts nothing.
export const prepareDitherImage =
  (canvas: Element): (quadVertices: number[]) =>
  (bayerMatrix: number[]) => Effect.Effect<PreparedDitherImage[]> =>
  quadVertices => bayerMatrix =>
  Effect.sync(() => {
    if (!(canvas instanceof HTMLCanvasElement)) return []
    const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: false })
    if (gl === null) return []
    const program = createShaderProgram(gl, ditheredImageShaders.vertex, ditheredImageShaders.fragment, 'dithered-image')
    if (program === undefined) {
      releaseContext(gl)
      return []
    }
    const imageTexture = gl.createTexture()
    const bayerTexture = gl.createTexture()
    const positionBuffer = gl.createBuffer()
    const textureBuffer = gl.createBuffer()
    if (imageTexture === null || bayerTexture === null || positionBuffer === null || textureBuffer === null) {
      if (imageTexture !== null) gl.deleteTexture(imageTexture)
      if (bayerTexture !== null) gl.deleteTexture(bayerTexture)
      if (positionBuffer !== null) gl.deleteBuffer(positionBuffer)
      if (textureBuffer !== null) gl.deleteBuffer(textureBuffer)
      deleteShaderProgram(gl, program)
      releaseContext(gl)
      return []
    }
    const position = gl.getAttribLocation(program.program, 'a_position')
    const textureCoordinate = gl.getAttribLocation(program.program, 'a_texCoord')
    if (position < 0 || textureCoordinate < 0) {
      gl.deleteTexture(imageTexture)
      gl.deleteTexture(bayerTexture)
      gl.deleteBuffer(positionBuffer)
      gl.deleteBuffer(textureBuffer)
      deleteShaderProgram(gl, program)
      releaseContext(gl)
      return []
    }

    gl.useProgram(program.program)
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
    gl.uniform1i(gl.getUniformLocation(program.program, 'u_bayer'), 1)
    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, imageTexture)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.uniform1i(gl.getUniformLocation(program.program, 'u_image'), 0)
    return [{
      canvas,
      gl,
      program,
      imageTexture,
      bayerTexture,
      positionBuffer,
      textureBuffer,
      textureCoordinate,
      uniforms: {
        resolution: gl.getUniformLocation(program.program, 'u_resolution'),
        time: gl.getUniformLocation(program.program, 'u_time'),
        ink: gl.getUniformLocation(program.program, 'u_ink'),
      },
    }]
  })

export const uploadDitherImage = (prepared: PreparedDitherImage): (image: Element) => void => image => {
  if (!(image instanceof HTMLImageElement)) return
  prepared.gl.bindTexture(prepared.gl.TEXTURE_2D, prepared.imageTexture)
  prepared.gl.texImage2D(prepared.gl.TEXTURE_2D, 0, prepared.gl.RGBA, prepared.gl.RGBA, prepared.gl.UNSIGNED_BYTE, image)
}

export const resizeDitherImage = (prepared: PreparedDitherImage): (layout: DitherLayout) => void => layout => {
  const gl = prepared.gl
  prepared.canvas.width = layout.canvasWidth
  prepared.canvas.height = layout.canvasHeight
  prepared.canvas.style.width = `${layout.cssWidth}px`
  prepared.canvas.style.height = `${layout.cssHeight}px`
  gl.viewport(0, 0, layout.canvasWidth, layout.canvasHeight)
  gl.uniform2f(prepared.uniforms.resolution, layout.canvasWidth, layout.canvasHeight)
  gl.bindBuffer(gl.ARRAY_BUFFER, prepared.textureBuffer)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(layout.textureCoordinates), gl.STATIC_DRAW)
  gl.vertexAttribPointer(prepared.textureCoordinate, 2, gl.FLOAT, false, 0, 0)
}

export const drawDitherImage = (prepared: PreparedDitherImage): (uniforms: DitherUniforms) => void => uniforms => {
  const gl = prepared.gl
  gl.uniform1f(prepared.uniforms.time, uniforms.time)
  gl.uniform3f(prepared.uniforms.ink, uniforms.red, uniforms.green, uniforms.blue)
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
}

export const disposeDitherImage = (prepared: PreparedDitherImage): Cleanup => () => {
  const { gl } = prepared
  gl.deleteTexture(prepared.imageTexture)
  gl.deleteTexture(prepared.bayerTexture)
  gl.deleteBuffer(prepared.positionBuffer)
  gl.deleteBuffer(prepared.textureBuffer)
  deleteShaderProgram(gl, prepared.program)
  releaseContext(gl)
}
