// WebGL mechanics for the hollow-mark canvas. PureScript (HollowMark.purs)
// owns every decision — this sibling only executes WebGL calls: one-time
// preparation, canvas resizing, per-frame uniform application, and teardown.
// The call sequences are byte-for-byte the ones the pre-migration mount used.
import { Effect } from 'effect'

import { createShaderProgram, deleteShaderProgram, releaseContext, type GlContext, type ShaderProgram } from './Gl.ts'

import { hollowMarkShaders } from './Shaders.ts'

type Cleanup = () => void
export type HollowUniforms = Readonly<{
  angle: number
  cubeAngle: number
  aspect: number
  time: number
  labHover: number
}>

export type PreparedHollowMark = {
  readonly canvas: HTMLCanvasElement
  readonly gl: GlContext
  readonly program: ShaderProgram
  readonly buffer: WebGLBuffer
  readonly moonTexture: WebGLTexture
  readonly moonImage: HTMLImageElement
  readonly vertexCount: number
  readonly uniforms: Readonly<{
    angle: WebGLUniformLocation | null
    cubeAngle: WebGLUniformLocation | null
    aspect: WebGLUniformLocation | null
    time: WebGLUniformLocation | null
    labHover: WebGLUniformLocation | null
  }>
  disposed: boolean
}

// Yields zero handles when the element is not a canvas, WebGL is missing, or
// the shaders fail — the PureScript side then mounts nothing.
export const prepareHollowMark =
  (element: Element): (vertices: number[]) => (vertexCount: number) =>
  (moonSrc: string) => Effect.Effect<PreparedHollowMark[]> =>
  vertices => vertexCount => moonSrc =>
  Effect.sync(() => {
    if (!(element instanceof HTMLCanvasElement)) return []
    const gl = element.getContext('webgl', {
      alpha: true,
      antialias: true,
      depth: true,
      premultipliedAlpha: true,
    })
    if (gl === null) return []
    const program = createShaderProgram(gl, hollowMarkShaders.vertex, hollowMarkShaders.fragment, 'hollow-mark')
    if (program === undefined) {
      releaseContext(gl)
      return []
    }
    const buffer = gl.createBuffer()
    const moonTexture = gl.createTexture()
    if (buffer === null || moonTexture === null) {
      if (buffer !== null) gl.deleteBuffer(buffer)
      if (moonTexture !== null) gl.deleteTexture(moonTexture)
      deleteShaderProgram(gl, program)
      releaseContext(gl)
      return []
    }

    const stride = 7 * Float32Array.BYTES_PER_ELEMENT
    const position = gl.getAttribLocation(program.program, 'a_position')
    const surfaceNormal = gl.getAttribLocation(program.program, 'a_normal')
    const region = gl.getAttribLocation(program.program, 'a_region')

    gl.useProgram(program.program)
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW)
    gl.enableVertexAttribArray(position)
    gl.vertexAttribPointer(position, 3, gl.FLOAT, false, stride, 0)
    gl.enableVertexAttribArray(surfaceNormal)
    gl.vertexAttribPointer(surfaceNormal, 3, gl.FLOAT, false, stride, 3 * Float32Array.BYTES_PER_ELEMENT)
    gl.enableVertexAttribArray(region)
    gl.vertexAttribPointer(region, 1, gl.FLOAT, false, stride, 6 * Float32Array.BYTES_PER_ELEMENT)
    gl.enable(gl.DEPTH_TEST)
    gl.depthFunc(gl.LEQUAL)
    gl.disable(gl.CULL_FACE)
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
    gl.uniform1i(gl.getUniformLocation(program.program, 'u_moon_texture'), 2)

    const prepared: PreparedHollowMark = {
      canvas: element,
      gl,
      program,
      buffer,
      moonTexture,
      moonImage: new Image(),
      vertexCount,
      uniforms: {
        angle: gl.getUniformLocation(program.program, 'u_angle'),
        cubeAngle: gl.getUniformLocation(program.program, 'u_cube_angle'),
        aspect: gl.getUniformLocation(program.program, 'u_aspect'),
        time: gl.getUniformLocation(program.program, 'u_time'),
        labHover: gl.getUniformLocation(program.program, 'u_lab_hover'),
      },
      disposed: false,
    }

    const uploadMoonTexture = (): void => {
      if (prepared.disposed || prepared.moonImage.naturalWidth === 0) return
      gl.activeTexture(gl.TEXTURE2)
      gl.bindTexture(gl.TEXTURE_2D, moonTexture)
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, prepared.moonImage)
    }
    prepared.moonImage.decoding = 'async'
    prepared.moonImage.addEventListener('load', uploadMoonTexture)
    prepared.moonImage.src = moonSrc

    return [prepared]
  })

export const resizeHollowMark =
  (prepared: PreparedHollowMark): (canvasWidth: number) => (canvasHeight: number) => void =>
  canvasWidth => canvasHeight => {
  prepared.canvas.width = canvasWidth
  prepared.canvas.height = canvasHeight
  prepared.gl.viewport(0, 0, canvasWidth, canvasHeight)
}

export const drawHollowMark = (prepared: PreparedHollowMark): (uniforms: HollowUniforms) => void => uniforms => {
  const gl = prepared.gl
  gl.clearColor(0, 0, 0, 0)
  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
  gl.uniform1f(prepared.uniforms.angle, uniforms.angle)
  gl.uniform1f(prepared.uniforms.cubeAngle, uniforms.cubeAngle)
  gl.uniform1f(prepared.uniforms.aspect, uniforms.aspect)
  gl.uniform1f(prepared.uniforms.time, uniforms.time)
  gl.uniform1f(prepared.uniforms.labHover, uniforms.labHover)
  gl.drawArrays(gl.TRIANGLES, 0, prepared.vertexCount)
}

export const disposeHollowMark = (prepared: PreparedHollowMark): Cleanup => () => {
  prepared.disposed = true
  const { gl } = prepared
  gl.deleteBuffer(prepared.buffer)
  gl.deleteTexture(prepared.moonTexture)
  deleteShaderProgram(gl, prepared.program)
  releaseContext(gl)
}
