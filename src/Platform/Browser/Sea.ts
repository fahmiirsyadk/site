// WebGL mechanics for the sea-footer canvas. PureScript (Sea.purs) owns every
// decision — this sibling only executes WebGL calls, in the same order the
// pre-migration mount used.
import { Effect } from 'effect'

import { createShaderProgram, releaseContext } from './Gl.ts'

import { seaFooterShaders } from './Shaders.ts'

type Cleanup = () => void
type GlContext = WebGL2RenderingContext

type ShaderProgram = Readonly<{
  program: WebGLProgram
  vertex: WebGLShader
  fragment: WebGLShader
}>

export type SeaUniforms = Readonly<{
  time: number
  resolutionX: number
  resolutionY: number
  cubeX: number
  cubeY: number
  velocityX: number
  velocityY: number
  uiDark: number
  intro: number
  labHover: number
}>

export type PreparedSea = Readonly<{
  canvas: HTMLCanvasElement
  gl: GlContext
  program: ShaderProgram
  vertexArray: WebGLVertexArrayObject | null
  uniforms: Readonly<{
    time: WebGLUniformLocation | null
    resolution: WebGLUniformLocation | null
    cubeOffset: WebGLUniformLocation | null
    cubeVelocity: WebGLUniformLocation | null
    dark: WebGLUniformLocation | null
    intro: WebGLUniformLocation | null
    ditherPixelSize: WebGLUniformLocation | null
    labHover: WebGLUniformLocation | null
  }>
}>

// Yields zero handles when the element is not a canvas, WebGL2 is missing, or
// the shaders fail — the PureScript side then mounts nothing.
export const prepareSea = (element: Element): Effect.Effect<ReadonlyArray<PreparedSea>> =>
  Effect.sync(() => {
    if (!(element instanceof HTMLCanvasElement)) return []
    const gl = element.getContext('webgl2', {
      alpha: true,
      premultipliedAlpha: false,
      antialias: false,
      depth: false,
      stencil: false,
    })
    if (gl === null) return []
    const program = createShaderProgram(gl, seaFooterShaders.vertex, seaFooterShaders.fragment, 'sea-footer')
    if (program === undefined) {
      releaseContext(gl)
      return []
    }
    const vertexArray = gl.createVertexArray()
    if (vertexArray === null) {
      gl.deleteProgram(program.program)
      gl.deleteShader(program.vertex)
      gl.deleteShader(program.fragment)
      releaseContext(gl)
      return []
    }
    gl.useProgram(program.program)
    gl.bindVertexArray(vertexArray)
    gl.uniform1f(gl.getUniformLocation(program.program, 'cloudQ'), 0.6)
    return [{
      canvas: element,
      gl,
      program,
      vertexArray,
      uniforms: {
        time: gl.getUniformLocation(program.program, 't'),
        resolution: gl.getUniformLocation(program.program, 'r'),
        cubeOffset: gl.getUniformLocation(program.program, 'cubeOff'),
        cubeVelocity: gl.getUniformLocation(program.program, 'cubeVel'),
        dark: gl.getUniformLocation(program.program, 'uiDark'),
        intro: gl.getUniformLocation(program.program, 'seaIntro'),
        ditherPixelSize: gl.getUniformLocation(program.program, 'ditherPx'),
        labHover: gl.getUniformLocation(program.program, 'labHover'),
      },
    }]
  })

export const resizeSea = (
  prepared: PreparedSea,
): (canvasWidth: number) => (canvasHeight: number) => (pixelRatio: number) => void =>
  canvasWidth => canvasHeight => pixelRatio => {
    prepared.canvas.width = canvasWidth
    prepared.canvas.height = canvasHeight
    prepared.gl.viewport(0, 0, canvasWidth, canvasHeight)
    prepared.gl.uniform1f(prepared.uniforms.ditherPixelSize, pixelRatio)
  }

export const drawSea = (prepared: PreparedSea): (uniforms: SeaUniforms) => void => uniforms => {
  const gl = prepared.gl
  gl.uniform1f(prepared.uniforms.time, uniforms.time)
  gl.uniform2f(prepared.uniforms.resolution, uniforms.resolutionX, uniforms.resolutionY)
  gl.uniform2f(prepared.uniforms.cubeOffset, uniforms.cubeX, uniforms.cubeY)
  gl.uniform2f(prepared.uniforms.cubeVelocity, uniforms.velocityX, uniforms.velocityY)
  gl.uniform1f(prepared.uniforms.dark, uniforms.uiDark)
  gl.uniform1f(prepared.uniforms.intro, uniforms.intro)
  gl.uniform1f(prepared.uniforms.labHover, uniforms.labHover)
  gl.clearColor(0, 0, 0, 0)
  gl.clear(gl.COLOR_BUFFER_BIT)
  gl.drawArrays(gl.TRIANGLES, 0, 3)
}

export const disposeSea = (prepared: PreparedSea): Cleanup => () => {
  const { gl } = prepared
  gl.deleteVertexArray(prepared.vertexArray)
  gl.deleteProgram(prepared.program.program)
  gl.deleteShader(prepared.program.vertex)
  gl.deleteShader(prepared.program.fragment)
  releaseContext(gl)
}
