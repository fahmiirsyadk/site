// Shared WebGL mechanics for the shader mounts. Pure helpers with no
// PureScript sibling — the mounts' .purs files import only the per-mount
// operations, which call through to these.
// Covers both the WebGL1 contexts (hollow-mark, dithered-image) and the WebGL2
// context (sea-footer): every helper below only uses calls shared by the two.
export type GlContext = WebGLRenderingContext | WebGL2RenderingContext

export type ShaderProgram = Readonly<{
  program: WebGLProgram
  vertex: WebGLShader
  fragment: WebGLShader
}>

export const compileShader = (gl: GlContext, type: number, source: string, label: string): WebGLShader | undefined => {
  const shader = gl.createShader(type)
  if (shader === null) return undefined
  gl.shaderSource(shader, source)
  gl.compileShader(shader)
  if (gl.getShaderParameter(shader, gl.COMPILE_STATUS)) return shader
  console.error(`${label} shader failed to compile`, gl.getShaderInfoLog(shader))
  gl.deleteShader(shader)
  return undefined
}

export const createShaderProgram = (
  gl: GlContext,
  vertex: string,
  fragment: string,
  label: string,
): ShaderProgram | undefined => {
  const vertexShader = compileShader(gl, gl.VERTEX_SHADER, vertex, `${label} vertex`)
  if (vertexShader === undefined) return undefined
  const fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER, fragment, `${label} fragment`)
  if (fragmentShader === undefined) {
    gl.deleteShader(vertexShader)
    return undefined
  }
  const program = gl.createProgram()
  if (program === null) {
    gl.deleteShader(vertexShader)
    gl.deleteShader(fragmentShader)
    return undefined
  }
  gl.attachShader(program, vertexShader)
  gl.attachShader(program, fragmentShader)
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error(`${label} program failed to link`, gl.getProgramInfoLog(program))
    gl.deleteProgram(program)
    gl.deleteShader(vertexShader)
    gl.deleteShader(fragmentShader)
    return undefined
  }
  return { program, vertex: vertexShader, fragment: fragmentShader }
}

export const deleteShaderProgram = (gl: GlContext, shaderProgram: ShaderProgram): void => {
  gl.deleteProgram(shaderProgram.program)
  gl.deleteShader(shaderProgram.vertex)
  gl.deleteShader(shaderProgram.fragment)
}

// Deleting resources does not free a context, and every navigation creates a
// fresh one per canvas. Release it so the page stays under the browser's
// live-context cap.
export const releaseContext = (gl: GlContext): void => {
  if (!gl.isContextLost()) {
    gl.getExtension('WEBGL_lose_context')?.loseContext()
  }
}
