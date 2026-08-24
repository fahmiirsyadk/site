attribute vec3 a_position;
attribute vec3 a_normal;
attribute float a_region;
uniform float u_angle;
uniform float u_cube_angle;
uniform float u_aspect;
uniform float u_time;
uniform float u_lab_hover;
varying vec3 v_normal;
varying vec3 v_position;
varying vec3 v_object_position;
varying float v_region;

float inertialEase(float progress) {
  float eased = progress * progress * progress
    * (progress * (progress * 6.0 - 15.0) + 10.0);
  float inertia = sin(progress * 3.14159265)
    * sin(progress * 6.2831853) * 0.035;
  return clamp(eased + inertia, 0.0, 1.0);
}

float shellTravel(float time, float delay) {
  float cycleTime = mod(time, 17.0);
  float forwardStart = 6.5 + delay;
  float backwardStart = 13.5 + delay;
  float turnDuration = 0.85;
  if (cycleTime < forwardStart) return 0.0;
  if (cycleTime < forwardStart + turnDuration) {
    return inertialEase((cycleTime - forwardStart) / turnDuration);
  }
  if (cycleTime < backwardStart) return 1.0;
  if (cycleTime < backwardStart + turnDuration) {
    return 1.0 - inertialEase((cycleTime - backwardStart) / turnDuration);
  }
  return 0.0;
}

void main() {
  float hoverAngle = u_lab_hover * 0.34906585;
  float ca = cos(u_angle + hoverAngle);
  float sa = sin(u_angle + hoverAngle);
  mat3 rotateY = mat3(
    ca, 0.0, -sa,
    0.0, 1.0, 0.0,
    sa, 0.0, ca
  );
  float tilt = -0.12 - u_lab_hover * 0.20;
  float ct = cos(tilt);
  float st = sin(tilt);
  mat3 rotateX = mat3(
    1.0, 0.0, 0.0,
    0.0, ct, -st,
    0.0, st, ct
  );
  float leftAngle = -shellTravel(u_time, 0.0) * 3.14159265;
  float leftCos = cos(leftAngle);
  float leftSin = sin(leftAngle);
  mat3 rotateLeftX = mat3(
    1.0, 0.0, 0.0,
    0.0, leftCos, -leftSin,
    0.0, leftSin, leftCos
  );
  float rightAngle = -shellTravel(u_time, 1.05) * 3.14159265;
  float rightCos = cos(rightAngle);
  float rightSin = sin(rightAngle);
  mat3 rotateRightX = mat3(
    1.0, 0.0, 0.0,
    0.0, rightCos, -rightSin,
    0.0, rightSin, rightCos
  );
  float cubeCos = cos(u_cube_angle);
  float cubeSin = sin(u_cube_angle);
  mat3 rotateCubeX = mat3(
    1.0, 0.0, 0.0,
    0.0, cubeCos, -cubeSin,
    0.0, cubeSin, cubeCos
  );
  float isLeftShell = 1.0 - step(2.5, a_region);
  float isRightShell = step(2.5, a_region) * (1.0 - step(5.5, a_region));
  float isCube = step(5.5, a_region);
  float splitOffset = 0.065;
  vec3 leftPosition = rotateLeftX * a_position + vec3(-splitOffset, 0.0, 0.0);
  vec3 rightPosition = rotateRightX * a_position + vec3(splitOffset, 0.0, 0.0);
  vec3 localShellPosition = leftPosition * isLeftShell + rightPosition * isRightShell;
  vec3 shellPosition = rotateX * rotateY * localShellPosition;
  vec3 cubeCenter = vec3(0.0);
  vec3 cubePosition = rotateX * rotateY
    * (cubeCenter + rotateCubeX * (a_position - cubeCenter));
  vec3 worldPosition = mix(shellPosition, cubePosition, isCube);
  vec3 viewPosition = worldPosition + vec3(0.0, 0.0, -3.35);
  float nearPlane = 0.1;
  float farPlane = 10.0;
  float focalLength = 2.72;
  gl_Position = vec4(
    viewPosition.x * focalLength / u_aspect,
    viewPosition.y * focalLength,
    ((farPlane + nearPlane) / (nearPlane - farPlane)) * viewPosition.z
      + (2.0 * farPlane * nearPlane) / (nearPlane - farPlane),
    -viewPosition.z
  );
  vec3 localShellNormal = rotateLeftX * a_normal * isLeftShell
    + rotateRightX * a_normal * isRightShell;
  vec3 shellNormal = rotateX * rotateY * localShellNormal;
  vec3 cubeNormal = rotateX * rotateY * rotateCubeX * a_normal;
  v_normal = normalize(mix(shellNormal, cubeNormal, isCube));
  v_position = worldPosition;
  v_object_position = a_position;
  v_region = a_region;
}
