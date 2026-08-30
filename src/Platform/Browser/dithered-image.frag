precision highp float;
uniform sampler2D u_image;
uniform sampler2D u_bayer;
uniform vec2 u_resolution;
uniform float u_time;
uniform vec3 u_ink;
varying vec2 v_texCoord;

float hash(vec2 value) {
  vec3 point = fract(vec3(value.xyx) * 0.1031);
  point += dot(point, point.yzx + 33.33);
  return fract((point.x + point.y) * point.z);
}

float animatedNoise(vec2 value, float time) {
  float current = hash(value + floor(time));
  float next = hash(value + floor(time) + 1.0);
  return mix(current, next, smoothstep(0.0, 1.0, fract(time)));
}

void main() {
  vec4 source = texture2D(u_image, v_texCoord);
  float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
  vec2 uv = gl_FragCoord.xy / u_resolution;
  float edge = smoothstep(0.0, 0.08, uv.x)
    * smoothstep(0.0, 0.08, 1.0 - uv.x)
    * smoothstep(0.0, 0.08, uv.y)
    * smoothstep(0.0, 0.08, 1.0 - uv.y);
  gray = mix(1.0, gray, edge);
  float noise = animatedNoise(gl_FragCoord.xy * 0.15, u_time * 0.8) - 0.5;
  float flicker = 0.08 * sin(u_time * 2.0 + hash(gl_FragCoord.xy * 0.2) * 6.28);
  float threshold = clamp(texture2D(u_bayer, mod(gl_FragCoord.xy, 4.0) / 4.0).r - 0.1 + (noise * 0.1 + flicker) * smoothstep(0.05, 0.3, gray), 0.001, 0.999);
  float dithered = step(threshold, gray);
  float inkAlpha = (1.0 - dithered) * source.a;
  gl_FragColor = vec4(u_ink, inkAlpha);
}
