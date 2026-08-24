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
uniform float ditherPx;
uniform float labHover;
#ifdef USE_TEXTURE_NOISE
uniform sampler2D uNoise;
#endif
const float LCL_PARAM=2.50;
const float WAVE_PARAM=2.70;
const float SHORE_PARAM=0.80;
const float BEACH_SLOPE=0.34;
const float H_DEEP=8.5;
const float H_MIN=0.16;
const float BREAK_RATIO=0.78;
const float RUNUP_EXTENT=0.42;
const float SWASH_F=0.34;
const float FOAM_DECAY=5.5;
const float BREAKER_TRAVEL=5.20;
const float BREAKER_POINT=2.00;
const float BREAKER_HEIGHT=0.58;
const float TOR2_SC=1.65;
const float WAVE_K = 0.78*0.25*WAVE_PARAM;
const float INV_PI = 0.31830988618;
#ifdef USE_TEXTURE_NOISE
float n(vec2 p){
  return texture(uNoise, fract(p*0.0078125)).r;
}
#else
float hash(vec2 p){
  return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float n(vec2 p){
  vec2 i=floor(p),f=fract(p);
  f=f*f*(3.-2.*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
#endif
float ditherHash(vec2 p){
  return fract(sin(dot(p,vec2(41.37,117.19)))*15731.743);
}
float fbm(vec2 p){
  return n(p)*.55+n(p*2.)*.3+n(p*4.)*.15;
}
float cloudDensity(vec2 pos,float tm,float q){
  vec2 p1=pos*vec2(0.065,0.15)+vec2(tm*0.24,-tm*0.07);
  vec2 p2=pos*vec2(0.10,0.19)+vec2(-tm*0.19,tm*0.06);
  float n1 = fbm(p1);
  float n2 = fbm(p2*0.94);
  float carve = fbm(pos*vec2(0.45,0.85)+vec2(tm*0.28,-tm*0.1));
  carve = smoothstep(0.38,0.62, carve);
  float c1=smoothstep(0.62,0.78,n1);
  float c2=smoothstep(0.64,0.80,n2);
  float clumps=max(c1,c2)*mix(0.35,1.0,carve);
  return pow(clamp(clumps,0.0,1.0), mix(1.15,1.35,q));
}
float sdBox3(vec3 p,vec3 b){
  vec3 q=abs(p)-b;
  return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0);
}
float rayBoxOffset(vec3 roL,vec3 rdL,vec3 off,vec3 hb){
  vec3 roB=roL-off;
  vec3 m=1.0/(rdL+1e-6);
  vec3 t1=(-hb-roB)*m;
  vec3 t2=(hb-roB)*m;
  vec3 tmi=min(t1,t2);
  vec3 tma=max(t1,t2);
  float tN=max(max(tmi.x,tmi.y),tmi.z);
  float tF=min(min(tma.x,tma.y),tma.z);
  return (tN<tF&&tF>0.0&&tN>0.0&&tN<1e4)?tN:-1.0;
}
float dToriiPl(vec3 p){
  float d=1e9;
  d=min(d,sdBox3(p-vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032)));
  d=min(d,sdBox3(p-vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032)));
  d=min(d,sdBox3(p-vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062)));
  d=min(d,sdBox3(p-vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052)));
  return d;
}
vec3 norToriiPl(vec3 p){
  float e=0.002;
  float a=dToriiPl(p);
  return normalize(vec3(dToriiPl(p+vec3(e,0,0))-a,dToriiPl(p+vec3(0,e,0))-a,dToriiPl(p+vec3(0,0,e))-a));
}
vec3 toriiWoodGrain(vec3 p,vec3 nrm){
#ifdef USE_TEXTURE_NOISE
  float g = n(p.xz*28.0);
  float gx = n(p.xz*28.0+vec2(0.008,0.0)) - g;
  float gz = n(p.xz*28.0+vec2(0.0,0.008)) - g;
  return normalize(nrm+vec3(gx*0.06,0.0,gz*0.06));
#else
  vec3 gv=vec3(0.);
  for(int i=0;i<3;i++){
    float f=1.0+float(i)*0.8;
    float g=n(p.xz*f*28.0)*0.5+n(p.xz*f*55.0)*0.25;
    float ge=n((p.xz*f+vec2(0.008,0.0))*28.0)*0.5+n((p.xz*f+vec2(0.008,0.0))*55.0)*0.25;
    float gn=n((p.xz*f+vec2(0.0,0.008))*28.0)*0.5+n((p.xz*f+vec2(0.0,0.008))*55.0)*0.25;
    gv+=vec3(ge-g,0.0,gn-g)*f;
  }
  return normalize(nrm+vec3(gv.x*0.06,0.0,gv.z*0.06));
#endif
}
float rayToriiT(vec3 ro,vec3 rd,vec3 cen,mat3 rot){
  vec3 roL=transpose(rot)*(ro-cen);
  vec3 rdL=transpose(rot)*rd;
  float tB=-1.0,tm;
  tm=rayBoxOffset(roL,rdL,vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  return tB;
}
float rayToriiTSc(vec3 ro,vec3 rd,vec3 cen,mat3 rot,float sc){
  vec3 roL=(transpose(rot)*(ro-cen))/sc;
  vec3 rdL=(transpose(rot)*rd)/sc;
  float tB=-1.0,tm;
  tm=rayBoxOffset(roL,rdL,vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052));
  if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  return tB;
}
mat3 rotX(float a){
  float s=sin(a),c=cos(a);
  return mat3(1,0,0,0,c,-s,0,s,c);
}
mat3 rotY(float a){
  float s=sin(a),c=cos(a);
  return mat3(c,0,s,0,1,0,-s,0,c);
}
mat3 rotZ(float a){
  float s=sin(a),c=cos(a);
  return mat3(c,-s,0,s,c,0,0,0,1);
}
float depthAt(float z){
  return clamp(max((z-SHORE_PARAM)*BEACH_SLOPE,0.0),H_MIN,H_DEEP);
}
vec3 shoalParams(float h){
  float hs=clamp(h,H_MIN,H_DEEP);
  float gain=clamp(sqrt(sqrt(H_DEEP/hs)),1.0,2.6);
  float kS=clamp(sqrt(H_DEEP/hs),1.0,3.2);
  float sharp=mix(1.0,2.4,1.0-hs/H_DEEP);
  return vec3(gain,kS,sharp);
}
float crestShape(float phase,float sharp){
  float s=0.5+0.5*sin(phase);
  float crest=pow(s,sharp)*2.0-1.0;
  float mean=2.0/(sharp+1.0)-1.0;
  return crest-mean;
}
float wave(vec2 p,float tm,vec3 sh){
  float gain=sh.x;
  float kS=sh.y;
  float sharp=sh.z;
  float refr=clamp((kS-1.0)/2.2,0.0,0.82);
  vec2 shoreNormal=vec2(0.0,1.0);
  vec2 d0=normalize(mix(normalize(vec2(0.9,1.1)),shoreNormal,refr));
  vec2 d1=normalize(mix(normalize(vec2(1.4,-0.8)),shoreNormal,refr));
  vec2 d2=normalize(mix(normalize(vec2(2.3,1.9)),shoreNormal,refr));
  vec2 d3=normalize(mix(normalize(vec2(3.7,-2.6)),shoreNormal,refr));
  vec2 d4=normalize(mix(normalize(vec2(6.4,3.1)),shoreNormal,refr));
  float lateralWarp=((n(vec2(p.x*0.12+tm*0.015,6.4))-0.5)*2.0+sin(p.x*0.29-tm*0.08)*0.35)*refr;
  float p0=dot(p,d0)*1.4213*kS-tm*1.7+lateralWarp*1.20;
  float p1=dot(p,d1)*1.6125*kS+tm*1.2-lateralWarp*0.75;
  vec2 leanP=p-d0*crestShape(p0,sharp)*0.06*gain-d1*crestShape(p1,sharp)*0.035*gain;
  p0=dot(leanP,d0)*1.4213*kS-tm*1.7+lateralWarp*1.20;
  p1=dot(leanP,d1)*1.6125*kS+tm*1.2-lateralWarp*0.75;
  float w=0.0;
  w+=crestShape(p0,sharp)*0.48;
  w+=crestShape(p1,sharp)*0.34;
  w+=sin(dot(leanP,d2)*2.9850*kS+tm*0.9+lateralWarp*1.45)*0.22;
  w+=sin(dot(leanP,d3)*4.5210*kS-tm*1.5-lateralWarp*1.80)*0.12;
  w+=sin(dot(leanP,d4)*7.1080*kS-tm*2.3+lateralWarp*2.30)*0.06;
  w+=sin(leanP.x*5.2*kS-tm*2.4)*sin(leanP.y*2.8*kS+tm*1.7)*0.06;
  return w*gain;
}
vec4 breakerState(float x,float tm){
  float broad=n(vec2(x*0.075,2.3));
  float medium=n(vec2(x*0.23,5.7));
  float fine=n(vec2(x*0.68,9.4));
  float alongshoreShape=broad*0.52+medium*0.33+fine*0.15;
  float timing=(broad-0.5)*0.42+(medium-0.5)*0.22+sin(x*0.19)*0.08;
  float phase=fract(tm*SWASH_F+timing);
  float travel=smoothstep(0.02,0.48,phase);
  float collapse=smoothstep(0.24,0.36,phase)*(1.0-smoothstep(0.58,0.74,phase));
  float amplitude=mix(0.12,1.50,smoothstep(0.16,0.84,alongshoreShape));
  float localBreakPoint=BREAKER_POINT*mix(0.68,1.38,broad);
  float scallopShape=pow(0.5+0.5*sin(x*1.18+sin(x*0.29+tm*0.12)),3.0);
  float scallop=scallopShape*mix(0.45,1.35,medium);
  float breakerLobe=sin(x*0.21+sin(x*0.07)*2.3+tm*0.12)*0.85;
  float edgeVariation=breakerLobe+sin(x*0.33+tm*0.22)*mix(0.24,0.64,broad)+(medium-0.5)*1.20-scallop;
  float breakerZ=SHORE_PARAM+mix(BREAKER_TRAVEL,localBreakPoint,travel)+edgeVariation;
  return vec4(phase,breakerZ,collapse,amplitude);
}
float shorelineWarp(float x,float tm){
  float broad=n(vec2(x*0.065+tm*0.012,13.7));
  float medium=n(vec2(x*0.19-tm*0.018,21.3));
  float fine=n(vec2(x*0.54+tm*0.025,34.9));
  float scallop=pow(0.5+0.5*sin(x*0.72+sin(x*0.17+tm*0.08)*1.6),3.0);
  float lobe=sin(x*0.31+sin(x*0.08-tm*0.04)*1.9)*0.72;
  return (broad-0.5)*1.35+(medium-0.5)*0.82+(fine-0.5)*0.24+lobe-scallop*0.95;
}
float surfaceHeight(vec2 p,float tm){
  vec3 sh=shoalParams(depthAt(p.y));
  float base=clamp(wave(p*0.65,tm,sh)*WAVE_K*0.28,-0.34,0.52);
  vec4 breaker=breakerState(p.x,tm);
  float ridgeLife=smoothstep(0.08,0.22,breaker.x)*(1.0-smoothstep(0.56,0.76,breaker.x));
  float ridgeStrength=clamp((breaker.w-0.12)/1.38,0.0,1.0);
  float ridgeDistance=(p.y-breaker.y)/mix(0.18,0.42,ridgeStrength);
  float ridge=exp(-ridgeDistance*ridgeDistance)*BREAKER_HEIGHT*ridgeLife*breaker.w;
  return base+ridge;
}
vec3 surfaceNormal(vec2 p,float tm){
  vec2 e=vec2(0.018,0.0);
  float left=surfaceHeight(p-e.xy,tm);
  float right=surfaceHeight(p+e.xy,tm);
  float near=surfaceHeight(p-e.yx,tm);
  float far=surfaceHeight(p+e.yx,tm);
  return normalize(vec3(left-right,e.x*2.0,near-far));
}
const float ATKINSON4[16]=float[16](0.0,12.0,3.0,15.0,8.0,4.0,11.0,7.0,2.0,14.0,1.0,13.0,10.0,6.0,9.0,5.0);
float atkinson4(vec2 p){
  int x=int(mod(floor(p.x),4.0));
  int y=int(mod(floor(p.y),4.0));
  return ATKINSON4[y*4+x]/16.0;
}
float ggxD(float NdotH,float rough){
  float a=rough*rough;
  float a2=a*a;
  float d=(NdotH*NdotH)*(a2-1.0)+1.0;
  return a2*INV_PI/(d*d);
}
float ggxG(float NdotV,float NdotL,float rough){
  float r=rough+1.0;
  float k=(r*r)/8.0;
  return NdotV/(NdotV*(1.0-k)+k)*NdotL/(NdotL*(1.0-k)+k);
}
float ggxF0(float NdotH,float NdotV,float NdotL,float f0){
  float f=f0+(1.0-f0)*pow(1.0-max(NdotH,0.0),5.0);
  return f*(NdotL*0.2+0.8)+(1.0-NdotL)*0.2;
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
  float isSea=0.0;
  float seaCov=0.0;
  float wetSand=0.0;
  float wetFragments=0.0;
  float foam=0.0;
  float foamCoverage=0.0;
  float coverage=0.0;
  int surface=-1;
  vec3 seaOnly=vec3(0.95,0.22,0.30);
  if(isSky<0.5){
    vec2 cubeDrift=vec2(sin(time*0.18)*0.32+sin(time*0.07+1.3)*0.10,cos(time*0.14)*0.18+sin(time*0.05)*0.08);
    vec2 cubeXZ=vec2(0.0,13.2)+cubeDrift+cubeOff;
    vec3 cubeSh=shoalParams(depthAt(cubeXZ.y));
    float wCube = wave(cubeXZ*0.65,time,cubeSh);
    float waterAtCube=surfaceHeight(cubeXZ,time);
    float perspZ=clamp((cubeXZ.y-4.0)/12.0,0.0,1.0);
    float size=mix(1.05,0.45,perspZ);
    float fl=0.06;
    float cubeShoreZ=SHORE_PARAM+wCube*WAVE_K*0.14;
    float seaDepth=clamp((cubeXZ.y-cubeShoreZ)/3.0,0.0,1.0);
    float bob=0.7*seaDepth;
    float cubeBaseY=waterAtCube-size*0.35+fl+mix(size*0.55,0.0,seaDepth);
    float bobY=sin(time*0.42+cubeXZ.x*0.35)*0.015*bob+cos(time*0.31-cubeXZ.y*0.26)*0.010*bob;
    vec3 cubePos=vec3(cubeXZ.x,cubeBaseY+bobY,cubeXZ.y);
    float ang=0.785398+sin(time*0.32)*0.12+cos(time*0.21)*0.05;
    float tiltZ=clamp(cubeVel.x*-0.15,-0.25,0.25)*mix(0.2,1.0,seaDepth);
    float tiltX=clamp(cubeVel.y*0.10,-0.20,0.20)*mix(0.2,1.0,seaDepth);
    float waveTilt=bobY*0.8*seaDepth;
    mat3 cubeRot=rotY(ang)*rotX(0.14+sin(time*0.8)*0.06*seaDepth+waveTilt+tiltX)*rotZ(0.09+cos(time*0.6)*0.04*seaDepth+tiltZ);
    float th=-1.0;
    vec3 hit=ro+rd*1e-3;
    if(rd.y<-0.001){
      th=-ro.y/rd.y;
      hit=ro+rd*th;
      for(int i=0;i<3;i++){
        float waterY=surfaceHeight(hit.xz,time);
        th=(waterY-ro.y)/rd.y;
        hit=ro+rd*th;
      }
    }
    float seaClip=(th>0.0)?th:1e9;
    vec2 p=hit.xz;
    float waterDepth=depthAt(p.y);
    vec3 sh=shoalParams(waterDepth);
    float wSea = wave(p*0.65,time,sh);
    float seaSurf=wSea*WAVE_K;
    vec4 breaker=breakerState(p.x,time);
    float ph=breaker.x;
    float breakerZ=breaker.y;
    float collapse=breaker.z;
    float amp=breaker.w;
    float swashPhase=clamp((ph-0.56)/0.44,0.0,1.0);
    float runup=smoothstep(0.0,0.18,swashPhase)*(1.0-smoothstep(0.18,1.0,swashPhase))*amp;
    float upRush=1.0-smoothstep(0.0,0.18,swashPhase);
    float drain=smoothstep(0.18,1.0,swashPhase);
    float shoreWarp=shorelineWarp(p.x,time);
    float shoreZ=SHORE_PARAM+shoreWarp-runup*RUNUP_EXTENT+seaSurf*0.14;
    float dist=p.y-shoreZ;
    float edgeWidth=mix(0.025+0.018*sh.x,0.012,D);
    seaCov=smoothstep(-edgeWidth,edgeWidth,dist);
    isSea=step(0.0,dist);
    float maxRunupZ=SHORE_PARAM+shoreWarp-amp*RUNUP_EXTENT*0.74;
    wetSand=(1.0-seaCov)*smoothstep(maxRunupZ-0.06,maxRunupZ+0.04,p.y)*(1.0-smoothstep(shoreZ-0.04,shoreZ+0.04,p.y));
    float wetPattern=fbm(vec2(p.x*0.56+time*0.025,p.y*1.75-time*0.04));
    wetFragments=smoothstep(0.34,0.70,wetPattern+0.18*n(vec2(p.x*1.4,p.y*2.2)));
    float breakerDistance=p.y-breakerZ;
    float foamFrontTravel=smoothstep(0.40,0.84,ph);
    float foamFrontZ=mix(breakerZ,shoreZ,foamFrontTravel);
    float foamFrontDistance=p.y-foamFrontZ;
    float ridgeLife=smoothstep(0.08,0.22,ph)*(1.0-smoothstep(0.58,0.78,ph));
    float foamNoise=fbm(vec2(p.x*1.15+time*0.10,p.y*3.4-time*0.32));
    float holes=smoothstep(0.22,0.72,foamNoise+0.22*n(vec2(p.x*3.1-time*0.18,p.y*5.2)));
    float heightVariation=clamp((amp-0.12)/1.38,0.0,1.0);
    float crestWidth=mix(0.12,0.55,heightVariation);
    float crestFoam=(1.0-smoothstep(0.04,crestWidth,abs(breakerDistance)))*ridgeLife*mix(0.68,1.0,holes)*mix(0.35,1.0,heightVariation);
    float plungingFace=smoothstep(mix(-0.34,-0.82,heightVariation),-0.04,breakerDistance)*(1.0-smoothstep(0.05,mix(0.18,0.36,heightVariation),breakerDistance))*collapse*mix(0.42,1.0,heightVariation);
    float spentLife=smoothstep(0.34,0.48,ph)*(1.0-smoothstep(0.88,0.99,ph));
    float brokenWater=smoothstep(-0.08,0.16,foamFrontDistance)*(1.0-smoothstep(0.90,2.20,foamFrontDistance))*spentLife*holes;
    float shoreFoamWidth=mix(0.05,0.30,heightVariation)*mix(0.72,1.18,n(vec2(p.x*0.41,17.2)));
    float shoreFoamSections=mix(0.08,1.0,holes)*smoothstep(0.18,0.62,heightVariation);
    float leadingFoam=(1.0-smoothstep(0.0,shoreFoamWidth,abs(dist)))*(0.52+0.48*upRush)*amp*smoothstep(0.66,0.78,ph)*shoreFoamSections;
    float landDistance=max(shoreZ-p.y,0.0);
    float backwashBend=(n(vec2(p.x*0.22-time*0.025,8.6))-0.5)*1.4;
    float backwashField=fbm(vec2(p.x*0.92+time*0.06,landDistance*1.55-time*0.15+backwashBend));
    float backwashRidge=1.0-smoothstep(0.055,0.17,abs(backwashField-0.52));
    float backwashBreak=smoothstep(0.40,0.68,n(vec2(p.x*0.34-time*0.04,landDistance*2.8+3.7)));
    float backwashPatches=wetSand*backwashRidge*backwashBreak*drain*exp(-landDistance*2.2);
    float foamTrail=wetSand*exp(-landDistance*FOAM_DECAY)*(0.18+0.62*drain)*mix(0.30,1.0,holes);
    float impactFoam=max(crestFoam,plungingFace*0.52);
    float movingFoam=max(brokenWater*0.78,leadingFoam*0.82);
    float residualFoam=max(backwashPatches*0.72,foamTrail*0.42);
    foam=clamp(max(impactFoam,max(movingFoam,residualFoam)),0.0,1.0);
    foamCoverage=clamp(max(impactFoam*0.94,max(movingFoam*0.72,residualFoam*0.56)),0.0,0.96);
    float depthTint=clamp(dist*0.42,0.,3.);
    seaOnly=mix(vec3(1.0,0.38,0.48),vec3(0.97,0.22,0.33),smoothstep(0.0,0.7,depthTint));
    seaOnly=mix(seaOnly,vec3(0.82,0.11,0.19),smoothstep(0.7,2.1,depthTint));
    vec3 roC=transpose(cubeRot)*(ro-cubePos);
    vec3 rdC=transpose(cubeRot)*rd;
    vec3 b=vec3(size);
    vec3 m=1.0/(rdC+1e-6);
    vec3 t1=(-b-roC)*m;
    vec3 t2=(b-roC)*m;
    vec3 tmin2=min(t1,t2);
    vec3 tmax2=max(t1,t2);
    float tN=max(max(tmin2.x,tmin2.y),tmin2.z);
    float tF=min(min(tmax2.x,tmax2.y),tmax2.z);
    bool hitCubeV=(tN<tF&&tF>0.0&&tN>0.0&&tN<seaClip);
    float torFarZ=26.2;
    vec2 tor0XZ=vec2(-10.8,torFarZ);
    vec2 tor1XZ=vec2(10.8,torFarZ);
    vec2 tor2XZ=vec2(0.0,35.0);
    float wT0=wave(tor0XZ*0.65,0.0,shoalParams(depthAt(tor0XZ.y)))*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    float wT1=wave(tor1XZ*0.65,0.0,shoalParams(depthAt(tor1XZ.y)))*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    float wT2=wave(tor2XZ*0.65,0.0,shoalParams(depthAt(tor2XZ.y)))*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    vec3 tor0Pos=vec3(tor0XZ.x,wT0,tor0XZ.y);
    vec3 tor1Pos=vec3(tor1XZ.x,wT1,tor1XZ.y);
    vec3 tor2Pos=vec3(tor2XZ.x,wT2,tor2XZ.y);
    mat3 tor0Rot=rotY(0.62)*rotX(0.05)*rotZ(0.03);
    mat3 tor1Rot=rotY(-0.58)*rotX(0.05)*rotZ(-0.03);
    mat3 tor2Rot=rotY(0.04)*rotX(0.04)*rotZ(0.0);
    float tTor0=rayToriiT(ro,rd,tor0Pos,tor0Rot);
    float tTor1=rayToriiT(ro,rd,tor1Pos,tor1Rot);
    float tTor2=rayToriiTSc(ro,rd,tor2Pos,tor2Rot,TOR2_SC);
    float tTor=1e9;
    int tid=0;
    if(tTor0>0.0){
      tTor=tTor0;
      tid=0;
    }
    if(tTor1>0.0&&tTor1<tTor){
      tTor=tTor1;
      tid=1;
    }
    if(tTor2>0.0&&tTor2<tTor){
      tTor=tTor2;
      tid=2;
    }
    if(tTor>1e8)tTor=-1.0;
    float tBest=1e9;
    int hid=-1;
    if(th>0.0&&rd.y<0.0){
      tBest=th;
      hid=0;
    }
    if(hitCubeV&&tN<tBest){
      tBest=tN;
      hid=1;
    }
    if(tTor>=0.0&&tTor<tBest){
      tBest=tTor;
      hid=2;
    }
    if(hid==-1)isSea=0.0;
    surface=hid;
    vec3 Lsun=normalize(vec3(0.3,0.8,0.4));
    if(hid==1){
      col=vec3(1.0);
      coverage=1.0;
      isSea=0.0;
    }
    else if(hid==2){
      vec3 ch=ro+rd*tTor;
      vec3 torCen=tor0Pos;
      mat3 torR=tor0Rot;
      float wTw=wT0;
      if(tid==1){
        torCen=tor1Pos;
        torR=tor1Rot;
        wTw=wT1;
      }
      else if(tid==2){
        torCen=tor2Pos;
        torR=tor2Rot;
        wTw=wT2;
      }
      float tsc=(tid==2)?TOR2_SC:1.0;
      vec3 pl=transpose(torR)*(ch-torCen)/tsc;
      vec3 nrmL=norToriiPl(pl);
      vec3 nrm=normalize(torR*nrmL);
      nrm=mix(nrm,toriiWoodGrain(pl,nrm),0.35);
      vec3 base=vec3(0.62,0.12,0.09);
      float top=max(0.0,nrm.y*0.5+0.5);
      float side=pow(max(0.0,abs(nrm.x)*0.55+abs(nrm.z)*0.45),1.15);
      float fres=pow(1.0-max(0.0,dot(nrm,-rd)),2.1);
      col=base*(0.48+top*0.42);
      col+=vec3(0.78,0.22,0.14)*side*0.28;
      col+=vec3(0.88,0.42,0.32)*fres*0.36;
      float wetLine=ch.y-wTw;
      float subm=1.0-smoothstep(-0.02,0.04,wetLine);
      col=mix(col,col*0.82+vec3(0.07,0.02,0.02),subm*0.42);
      col+=exp(-abs(wetLine)*80.0)*0.09*vec3(0.98,0.55,0.42);
      float spec=pow(max(0.,dot(reflect(-Lsun,nrm),-rd)),56.0);
      col+=spec*0.28*vec3(1.0,0.72,0.55);
      float rim=pow(max(0.0,1.0-abs(dot(nrm,rd))),3.0)*0.45;
      col+=rim*vec3(1.0,0.48,0.28)*(0.5+0.5*smoothstep(0.3,0.7,pl.y));
      coverage=0.94;
      isSea=0.0;
    }
    else if(hid==0){
      vec3 sand=mix(vec3(1.0),pageBg*1.02,D);
      sand+=(fbm(p*11.0)-0.5)*0.008;
      if(seaCov>0.001){
        float depth=clamp(dist*0.42,0.,3.);
        vec3 seaShallow=vec3(1.0,0.38,0.48);
        vec3 seaMid=vec3(0.97,0.22,0.33);
        vec3 seaDeep=vec3(0.82,0.11,0.19);
        vec3 sea=mix(seaShallow,seaMid,smoothstep(0.0,0.7,depth));
        sea=mix(sea,seaDeep,smoothstep(0.7,2.1,depth));
        vec2 luv=p*1.5;
        float lclA=pow(fbm(luv+vec2(time*0.30,-time*0.08)),9.5);
        float lclB=pow(fbm(luv*1.9-vec2(time*0.22,time*0.05)),12.0);
        float lcl=clamp(lclA*0.70+lclB*0.45,0.0,1.0);
        float lclDark=0.45*D;
        vec3 lclCoral=mix(vec3(1.0,0.66,0.46),vec3(0.20,0.17,0.16),lclDark);
        vec3 lclWarm=mix(vec3(1.0,0.82,0.66),vec3(0.24,0.20,0.18),lclDark);
        sea+=lcl*0.72*LCL_PARAM*lclCoral;
        sea+=pow(fbm(luv*3.3+time*0.18),13.6)*0.20*LCL_PARAM*lclWarm;
        col=sea;
        vec2 seaC0=p*vec2(0.071,0.056)+vec2(time*0.055,-time*0.02);
        vec2 seaC1=p*vec2(0.065,0.051)*0.92+vec2(-time*0.048,time*0.015);
        float sdSea0=cloudDensity(seaC0,time,cloudQ);
        float sdSea1=cloudDensity(seaC1,time+4.5,cloudQ);
        float cMix=max(sdSea0,sdSea1);
        float openW=smoothstep(0.08,1.4,dist*0.42);
        float cMix2=cMix*cMix;
        float cSh=smoothstep(0.42,0.92,cMix)*(0.42+0.58*cMix2)*openW;
        float cRf=max(smoothstep(0.32,0.62,cMix)*(1.0-cSh*0.75),0.0)*openW;
        col*=mix(vec3(1.0),vec3(0.58,0.60,0.74),cSh*0.62);
        col+=cRf*vec3(0.06+0.04*cMix,0.065+0.035*cMix,0.085+0.04*cMix);
        vec3 seaN=surfaceNormal(p,time);
        vec3 Hsun=Lsun+(-rd);
        float hLen=length(Hsun);
        vec3 halfVec=hLen>1e-4?Hsun/hLen:vec3(0.0,1.0,0.0);
        float NdotH=max(0.0,dot(seaN,halfVec));
        float NdotV=max(0.0,dot(seaN,-rd));
        float NdotL=max(0.0,dot(seaN,Lsun));
        float rough=0.18+0.12*fbm(p*2.2+time*0.15);
        float f0=0.02;
        float Dggx=ggxD(NdotH,rough);
        float Gggx=ggxG(NdotV,NdotL,rough);
        float Fggx=ggxF0(NdotH,NdotV,NdotL,f0);
        float specGlint=Dggx*Gggx*Fggx*0.42*smoothstep(0.0,0.35,dist);
        col+=specGlint*vec3(1.0,0.92,0.88);
        float shade=clamp(0.58+0.34*NdotL+0.18*specGlint,0.45,1.0);
        float seaDensity=mix(0.55,0.92,smoothstep(0.0,2.4,depth))*shade;
        float faceShade=smoothstep(-0.72,-0.06,breakerDistance)*(1.0-smoothstep(0.10,0.34,breakerDistance))*collapse;
        sea=mix(sea,vec3(0.42,0.025,0.065),faceShade*0.76);
        col=mix(col,sea,faceShade*0.72);
        coverage=seaCov*seaDensity;
        coverage=mix(coverage,0.98,faceShade*0.52);
        vec3 foamCol=vec3(1.0);
        col=mix(col,foamCol,foam);
        coverage=max(coverage,foam*0.98);
      }
      else{
        float wetShade=mix(0.18,0.45,wetSand);
        col=mix(sand,sand*0.78+mix(vec3(0.04,0.03,0.03),vec3(0.10,0.06,0.06),D),wetSand*0.72);
        coverage=wetSand*wetShade;
        vec3 foamCol=vec3(1.0);
        col=mix(col,foamCol,foam);
        coverage=max(coverage,foam*0.98);
      }
    }
  }
  float cloudH=-uv.y;
  float cloudBand=smoothstep(0.0,0.018,cloudH)*(1.0-smoothstep(0.055,0.20,cloudH));
  if(cloudBand>0.0){
    float cq=clamp(cloudQ,0.2,1.0);
    vec2 scBase=vec2(uv.x*7.5,cloudH*22.0);
    vec2 cd0UV=scBase+vec2(time*0.055,-time*0.02);
    vec2 cd1UV=scBase*0.92+vec2(-time*0.048,time*0.015);
    vec2 cd2UV=scBase*0.84+vec2(time*0.034,time*0.011);
    float sd0=cloudDensity(cd0UV,time,cq);
    float sd1=cloudDensity(cd1UV,time+4.5,cq);
    float sd2=cloudDensity(cd2UV,time+9.0,cq);
    float sa0=smoothstep(0.48,0.82,sd0);
    float sa1=smoothstep(0.50,0.84,sd1);
    float sa2=smoothstep(0.52,0.86,sd2);
    float heightGrad=1.0-smoothstep(0.025,0.16,cloudH);
    vec3 seaTint=col;
    float lowerW=(1.0-heightGrad);
    vec3 cloudBot=vec3(0.90,0.88,0.91);
    vec3 botCol=mix(cloudBot,seaTint,isSea*0.20*lowerW);
    vec3 cloudTop=mix(vec3(1.0),seaTint,isSea*0.06);
    vec3 cc0=mix(botCol,cloudTop,heightGrad);
    float cMask=cloudBand*mix(0.5,1.0,cq);
    float cw=mix(0.62,1.0,cq);
    col=mix(col,cc0,sa0*cMask*0.72*cw);
    vec3 cc1=mix(botCol*0.97,cloudTop*0.98,heightGrad)*(1.0-sa0*0.20);
    col=mix(col,cc1,sa1*(1.0-sa0*0.55)*cMask*0.58*cw);
    vec3 cc2=mix(botCol*0.94,cloudTop*0.96,heightGrad)*(1.0-sa0*0.16)*(1.0-sa1*0.14);
    col=mix(col,cc2,sa2*(1.0-sa0*0.45)*(1.0-sa1*0.35)*cMask*0.48*cw);
    float cCore=smoothstep(0.82,0.97,sd0)*cMask*mix(0.35,1.0,cq);
    vec3 coreCol=mix(vec3(1.0),seaTint,isSea*0.04);
    col=mix(col,coreCol,cCore*0.62);
    col+=seaTint*sa0*cMask*isSea*0.035*lowerW;
    float cloudCov=cMask*clamp(sa0*0.72*cw+sa1*(1.0-sa0*0.55)*0.58*cw+sa2*(1.0-sa0*0.45)*(1.0-sa1*0.35)*0.48*cw+cCore*0.62,0.0,1.0);
    coverage=max(coverage,cloudCov*mix(0.5,1.0,cq));
  }
  if(surface==2){
    col=mix(col,col*1.32+vec3(0.025,0.012,0.008),D);
  }
  col=clamp(col,0.0,1.0);
  float monochrome=dot(col,vec3(0.299,0.587,0.114));
  col=mix(col,vec3(monochrome),labHover);
  if(surface==0){
    if(seaCov>0.001){
      float luminance=dot(col,vec3(0.299,0.587,0.114));
      float waterInk=1.0-smoothstep(0.16,0.88,luminance);
      float detailRate=smoothstep(0.035,0.16,fwidth(luminance));
      waterInk=mix(waterInk,0.5+(waterInk-0.5)*0.62,detailRate);
      float tonalCoverage=mix(0.16,0.96,pow(waterInk,0.82));
      coverage=seaCov*tonalCoverage;
      coverage=max(coverage,foamCoverage);
    }
    else{
      float wetInk=mix(0.12,0.42,wetSand)*mix(1.0,0.10,D)*mix(0.18,1.0,wetFragments);
      coverage=max(wetSand*wetInk,foamCoverage);
    }
  }
  if(surface==0){
    float horizonFade=1.0-smoothstep(-0.055,0.0,rd.y);
    coverage=clamp(coverage*horizonFade,0.0,1.0);
  }
  vec2 ditherCoord=gl_FragCoord.xy/max(ditherPx,1.0);
  float thresholdJitter=(ditherHash(floor(ditherCoord))-0.5)*0.07;
  float threshold=clamp(atkinson4(ditherCoord)+thresholdJitter,0.001,0.999);
  o=vec4(col,step(threshold,coverage));
}
