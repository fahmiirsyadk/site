#version 300 es
precision highp float;
out vec4 o;
uniform float t;
uniform vec2 r;
uniform vec2 cubeOff;
uniform vec2 cubeVel;
uniform float cloudQ;
uniform float uiDark;
uniform float seaIntro;

mat3 rotX(float a){float s=sin(a),c=cos(a);return mat3(1,0,0,0,c,-s,0,s,c);}

float wave(vec2 p,float tm){
  float w=0.;
  w+=sin(p.x*0.9+p.y*1.1-tm*1.7)*0.48;
  w+=sin(p.x*1.4-p.y*0.8+tm*1.2)*0.34;
  return w;
}

void main(){
  vec2 uv=(gl_FragCoord.xy-0.5*r)/r.y;
  float camT=smoothstep(0.0,1.0,clamp(seaIntro,0.0,1.0));
  vec3 ro=mix(vec3(0.0,2.5,-30.0),vec3(0.0,1.8,-7.5),camT);
  vec3 rd=normalize(vec3(uv,1.6));
  rd=rotX(0.05)*rd;
  float isSky=step(0.26,rd.y);
  float time=t*0.85;
  float D=uiDark;
  vec3 pageBg=vec3(0.090196);
  vec3 skyPaper=mix(vec3(1.0),pageBg,D);
  vec3 col=skyPaper;
  if(isSky<0.5){
    float th=-ro.y/rd.y;
    vec3 hit=ro+rd*((th>0.0)?th:1e-3);
    vec2 p=hit.xz;
    float wSea=wave(p*0.65,time);
    float seaSurf=wSea*0.78*0.25*2.7;
    float shorePulse=sin(p.x*0.8-time*0.9)*0.06;
    float shoreZ=0.80+seaSurf*0.95+shorePulse;
    float dist=p.y-shoreZ;
    float isSea=step(0.0,dist);
    float depthTint=clamp(dist*0.42,0.,3.);
    vec3 seaShallow=vec3(1.0,0.38,0.48);
    vec3 seaMid=vec3(0.97,0.22,0.33);
    vec3 seaDeep=vec3(0.82,0.11,0.19);
    vec3 sea=mix(seaShallow,seaMid,smoothstep(0.0,0.7,depthTint));
    sea=mix(sea,seaDeep,smoothstep(0.7,2.1,depthTint));
    vec3 sand=mix(vec3(1.0),pageBg*1.02,D);
    col=mix(sand,sea,isSea);
    float spec=pow(max(0.,dot(reflect(-normalize(vec3(0.3,0.8,0.4)),vec3(0.,1.,0.)),-rd)),32.0);
    col+=spec*0.15*vec3(1.0,0.92,0.88)*isSea;
  }
  col=clamp(col,0.0,1.0);
  float skyA=1.0-smoothstep(0.34,0.99,rd.y);
  float outASky=mix(1.0,skyA,isSky);
  float outA=mix(outASky,1.0,D);
  o=vec4(col,outA);
}
