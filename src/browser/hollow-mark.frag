precision highp float;
uniform float u_time;
uniform float u_lab_hover;
uniform sampler2D u_moon_texture;
varying vec3 v_normal;
varying vec3 v_position;
varying vec3 v_object_position;
varying float v_region;

float hash(vec2 value) {
  return fract(sin(dot(value, vec2(41.37, 117.19))) * 15731.743);
}

float animatedNoise(vec2 value, float time) {
  float current = hash(value + floor(time));
  float next = hash(value + floor(time) + 1.0);
  return mix(current, next, smoothstep(0.0, 1.0, fract(time)));
}

float bayer4(vec2 value) {
  vec2 cell = mod(floor(value), 4.0);
  if (cell.y < 1.0) {
    if (cell.x < 1.0) return 0.0 / 16.0;
    if (cell.x < 2.0) return 12.0 / 16.0;
    if (cell.x < 3.0) return 3.0 / 16.0;
    return 15.0 / 16.0;
  }
  if (cell.y < 2.0) {
    if (cell.x < 1.0) return 8.0 / 16.0;
    if (cell.x < 2.0) return 4.0 / 16.0;
    if (cell.x < 3.0) return 11.0 / 16.0;
    return 7.0 / 16.0;
  }
  if (cell.y < 3.0) {
    if (cell.x < 1.0) return 2.0 / 16.0;
    if (cell.x < 2.0) return 14.0 / 16.0;
    if (cell.x < 3.0) return 1.0 / 16.0;
    return 13.0 / 16.0;
  }
  if (cell.x < 1.0) return 10.0 / 16.0;
  if (cell.x < 2.0) return 6.0 / 16.0;
  if (cell.x < 3.0) return 9.0 / 16.0;
  return 5.0 / 16.0;
}

float inertialEase(float progress) {
  float eased = progress * progress * progress
    * (progress * (progress * 6.0 - 15.0) + 10.0);
  float inertia = sin(progress * 3.14159265)
    * sin(progress * 6.2831853) * 0.035;
  return clamp(eased + inertia, 0.0, 1.0);
}

float ballEase(float progress) {
  if (progress < 0.14) {
    return -0.045 * sin(progress / 0.14 * 3.14159265);
  }
  if (progress < 0.82) {
    return inertialEase((progress - 0.14) / 0.68);
  }
  float settle = (progress - 0.82) / 0.18;
  float decay = (1.0 - settle) * (1.0 - settle);
  return 1.0 + sin(settle * 6.2831853) * 0.075 * decay;
}

float eyeOrbitTravel(float time) {
  float cycleTime = mod(time, 17.0);
  if (cycleTime < 5.5) return 0.0;
  if (cycleTime < 6.5) return ballEase(cycleTime - 5.5);
  if (cycleTime < 12.5) return 1.0;
  if (cycleTime < 13.5) return 1.0 - ballEase(cycleTime - 12.5);
  return 0.0;
}

float eyeMotionProgress(float time) {
  float cycleTime = mod(time, 17.0);
  if (cycleTime >= 5.5 && cycleTime < 6.5) return cycleTime - 5.5;
  if (cycleTime >= 12.5 && cycleTime < 13.5) return cycleTime - 12.5;
  return -1.0;
}

float eyeDeformation(float progress) {
  if (progress < 0.0) return 0.0;
  float press = -0.35 * exp(-pow((progress - 0.08) / 0.045, 2.0));
  float flight = 1.15 * sin(
    smoothstep(0.12, 0.82, progress) * 3.14159265
  );
  float impact = -0.38 * exp(-pow((progress - 0.84) / 0.055, 2.0));
  float rebound = 0.20 * exp(-pow((progress - 0.94) / 0.05, 2.0));
  return press + flight + impact + rebound;
}

void main() {
  vec3 normal = normalize(v_normal);
  vec3 lightPosition = vec3(2.6, 2.8, 3.6);
  vec3 lightDirection = normalize(lightPosition - v_position);
  vec3 viewDirection = normalize(vec3(0.0, 0.0, 3.35) - v_position);
  float diffuse = max(dot(normal, lightDirection), 0.0);
  float isLeftOuterShell = 1.0 - step(0.5, v_region);
  float isLeftCavity = step(0.5, v_region) * (1.0 - step(1.5, v_region));
  float isRightOuterShell = step(2.5, v_region) * (1.0 - step(3.5, v_region));
  float isRightCavity = step(3.5, v_region) * (1.0 - step(4.5, v_region));
  float isCavity = isLeftCavity + isRightCavity;
  float isCube = step(5.5, v_region);
  float isOuterShell = isLeftOuterShell + isRightOuterShell;
  vec3 coral = vec3(1.0, 0.294, 0.149);
  vec3 cavityShadow = vec3(0.60, 0.015, 0.005);
  vec3 cavityLight = vec3(0.95, 0.13, 0.025);
  vec3 cavityColor = mix(cavityShadow, cavityLight, 0.18 + diffuse * 0.82);
  vec3 color = mix(coral, cavityColor, isCavity);
  vec3 cubeShadow = vec3(1.0, 0.78, 0.70);
  vec3 cubeColor = mix(cubeShadow, vec3(1.0), 0.32 + diffuse * 0.68);
  color = mix(color, cubeColor, isCube);
  vec3 lunarDirection = normalize(v_object_position);
  float longitude = atan(lunarDirection.z, lunarDirection.x);
  float latitude = asin(clamp(lunarDirection.y, -1.0, 1.0));
  vec2 moonUv = vec2(
    longitude / 6.2831853 + 0.5,
    latitude / 3.14159265 + 0.5
  );
  moonUv = (moonUv - 0.5) * 0.62 + 0.5;
  vec3 moonSample = texture2D(u_moon_texture, moonUv).rgb;
  float moonLuminance = dot(moonSample, vec3(0.299, 0.587, 0.114));
  float moonValue = smoothstep(0.60, 0.80, moonLuminance);
  vec3 moonShadow = vec3(0.50, 0.010, 0.002);
  float edge = pow(1.0 - abs(dot(normal, viewDirection)), 3.0);
  float glanceCycle = u_time * 1.35;
  float glancePhase = floor(glanceCycle);
  float glanceBlend = smoothstep(0.0, 0.18, fract(glanceCycle));
  vec2 previousGlance = vec2(
    hash(vec2(glancePhase, 3.1)),
    hash(vec2(glancePhase, 7.7))
  ) - 0.5;
  vec2 nextGlance = vec2(
    hash(vec2(glancePhase + 1.0, 3.1)),
    hash(vec2(glancePhase + 1.0, 7.7))
  ) - 0.5;
  vec2 anxiousOffset = mix(previousGlance, nextGlance, glanceBlend) * vec2(0.055, 0.026);
  float eyeOrbit = eyeOrbitTravel(u_time);
  float eyeX = -0.42 + anxiousOffset.x;
  float eyePhi = 0.18 - eyeOrbit * 3.14159265 + anxiousOffset.y * 1.8;
  float eyeRingRadius = sqrt(1.0 - eyeX * eyeX);
  vec3 eyeDirection = normalize(vec3(
    eyeX,
    sin(eyePhi) * eyeRingRadius,
    cos(eyePhi) * eyeRingRadius
  ));
  vec3 eyeTangent = normalize(vec3(0.0, cos(eyePhi), -sin(eyePhi)));
  vec3 eyeBitangent = normalize(cross(eyeDirection, eyeTangent));
  vec3 eyeDelta = normalize(v_object_position) - eyeDirection;
  float deformation = eyeDeformation(eyeMotionProgress(u_time));
  float alongRadius = 0.115 * (1.0 + deformation);
  float acrossRadius = 0.115 * (1.0 - deformation * 0.65);
  float eyeDistance = length(vec2(
    dot(eyeDelta, eyeTangent) / alongRadius,
    dot(eyeDelta, eyeBitangent) / acrossRadius
  ));
  float eye = 1.0 - smoothstep(
    0.94,
    1.06,
    eyeDistance
  );
  float eyeMask = eye * isLeftOuterShell;
  float motionProgress = eyeMotionProgress(u_time);
  float motionActive = motionProgress < 0.0
    ? 0.0
    : sin(motionProgress * 3.14159265);
  vec2 ripplePosition = vec2(
    dot(eyeDelta, eyeTangent),
    dot(eyeDelta, eyeBitangent)
  );
  float rippleRadius = length(ripplePosition);
  float rippleCenter = max(motionProgress, 0.0) * 0.42;
  float rippleBand = exp(-pow((rippleRadius - rippleCenter) / 0.105, 2.0));
  float rippleWave = motionActive
    * rippleBand
    * sin(rippleRadius * 68.0 - max(motionProgress, 0.0) * 20.0);
  vec2 rippleDirection = rippleRadius > 0.001
    ? ripplePosition / rippleRadius
    : vec2(0.0);
  vec2 liquidOffset = rippleDirection * rippleWave * 7.0;
  vec2 ditherCell = floor(gl_FragCoord.xy + liquidOffset);
  float temporalNoise = animatedNoise(ditherCell * 0.15, u_time * 0.8) - 0.5;
  float flicker = 0.012 * sin(
    u_time * 2.0 + hash(ditherCell * 0.2) * 6.28
  );
  float threshold = clamp(
    bayer4(ditherCell) + temporalNoise * 0.03 + flicker,
    0.001,
    0.999
  );
  float surfaceLight = mix(0.72 + diffuse * 0.26, 0.58 + diffuse * 0.38, isCavity);
  float moonDensity = moonValue;
  float coverage = clamp(
    surfaceLight + edge * 0.18,
    0.0,
    0.98
  );
  coverage = max(coverage, edge * 0.98);
  coverage = max(coverage, eyeMask);
  coverage = mix(coverage, 0.86, isCube);
  float dithered = step(threshold, coverage);
  float textureDither = step(threshold, moonDensity);
  vec3 textureColor = mix(moonShadow, coral, textureDither);
  color = mix(color, textureColor, isOuterShell);
  color = mix(color, vec3(1.0), eyeMask);
  float monochrome = dot(color, vec3(0.299, 0.587, 0.114));
  color = mix(color, vec3(monochrome), u_lab_hover);
  float alpha = mix(dithered, 1.0, isOuterShell);
  alpha = mix(alpha, 1.0, isCube);
  gl_FragColor = vec4(color, alpha);
}
