type GlContext = WebGLRenderingContext | WebGL2RenderingContext

type ShaderProgram = Readonly<{
  program: WebGLProgram
  vertex: WebGLShader
  fragment: WebGLShader
}>

export const noop = (): void => undefined

export const compileShader = (
  gl: GlContext,
  type: number,
  source: string,
  label: string,
): WebGLShader | undefined => {
  const shader = gl.createShader(type)
  if (shader === null) {
    return undefined
  }
  gl.shaderSource(shader, source)
  gl.compileShader(shader)
  if (gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    return shader
  }
  console.error(`${label} shader failed to compile`, gl.getShaderInfoLog(shader))
  gl.deleteShader(shader)
  return undefined
}

export const createShaderProgram = (
  gl: GlContext,
  vertexSource: string,
  fragmentSource: string,
  label: string,
): ShaderProgram | undefined => {
  const vertex = compileShader(gl, gl.VERTEX_SHADER, vertexSource, `${label} vertex`)
  if (vertex === undefined) {
    return undefined
  }
  const fragment = compileShader(gl, gl.FRAGMENT_SHADER, fragmentSource, `${label} fragment`)
  if (fragment === undefined) {
    gl.deleteShader(vertex)
    return undefined
  }
  const program = gl.createProgram()
  if (program === null) {
    gl.deleteShader(vertex)
    gl.deleteShader(fragment)
    return undefined
  }
  gl.attachShader(program, vertex)
  gl.attachShader(program, fragment)
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error(`${label} program failed to link`, gl.getProgramInfoLog(program))
    gl.deleteProgram(program)
    gl.deleteShader(vertex)
    gl.deleteShader(fragment)
    return undefined
  }
  return { program, vertex, fragment }
}

export const deleteShaderProgram = (gl: GlContext, shaderProgram: ShaderProgram): void => {
  gl.deleteProgram(shaderProgram.program)
  gl.deleteShader(shaderProgram.vertex)
  gl.deleteShader(shaderProgram.fragment)
}

export const releaseContext = (gl: GlContext): void => {
  if (!gl.isContextLost()) {
    gl.getExtension('WEBGL_lose_context')?.loseContext()
  }
}
