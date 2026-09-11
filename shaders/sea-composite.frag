#version 300 es
precision highp float;
out vec4 o;
uniform sampler2D seaTexture;
uniform vec2 outputSize;
uniform float ditherPx;
const float ATKINSON4[16]=float[16](0.0,12.0,3.0,15.0,8.0,4.0,11.0,7.0,2.0,14.0,1.0,13.0,10.0,6.0,9.0,5.0);
float atkinson4(vec2 p){
  ivec2 cell=ivec2(mod(floor(p),4.0));
  return ATKINSON4[cell.y*4+cell.x]/16.0;
}
float ditherHash(vec2 p){
  return fract(sin(dot(p,vec2(41.37,117.19)))*15731.743);
}
void main(){
  vec2 ditherCoord=gl_FragCoord.xy/max(ditherPx,1.0);
  float jitter=(ditherHash(floor(ditherCoord))-0.5)*0.07;
  float threshold=clamp(atkinson4(ditherCoord)+jitter,0.001,0.999);
  vec4 sea=texture(seaTexture,gl_FragCoord.xy/outputSize);
  o=vec4(sea.rgb,step(threshold,sea.a));
}
