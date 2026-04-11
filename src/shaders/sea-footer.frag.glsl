#version 300 es
precision highp float;
out vec4 o;

uniform float t;
uniform vec2 r;
uniform vec2 cubeOff;
uniform vec2 cubeVel;
uniform float cloudQ;
uniform float uiDark;

#ifdef USE_TEXTURE_NOISE
uniform sampler2D uNoise;
#endif

const float LCL_PARAM=2.50;
const float WAVE_PARAM=2.70;
const float FOAM_PARAM=2.50;
const float SHORE_PARAM=0.80;
const float TOR2_SC=1.65;
const float WAVE_K = 0.78*0.25*WAVE_PARAM; // precomputed
const float INV_PI = 0.31830988618;

// ---- noise ----
#ifdef USE_TEXTURE_NOISE
float n(vec2 p){ return texture(uNoise, fract(p*0.0078125)).r; }
#else
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
#endif

float fbm(vec2 p){return n(p)*.55+n(p*2.)*.3+n(p*4.)*.15;}
float fbm5(vec2 p){float s=0.;float a=0.5;float f=1.0;for(int i=0;i<5;i++){s+=a*n(p*f);f*=2.1;a*=0.48;}return s;}

float cloudDensity(vec2 pos,float tm,float q){
  vec2 p1=pos*vec2(0.065,0.15)+vec2(tm*0.24,-tm*0.07);
  vec2 p2=pos*vec2(0.10,0.19)+vec2(-tm*0.19,tm*0.06);
  float n1 = q>0.55? fbm5(p1) : fbm(p1);
  float n2 = q>0.55? fbm5(p2) : fbm(p2*0.94);
  float carve = q>0.55? fbm5(pos*vec2(0.45,0.85)+vec2(tm*0.28,-tm*0.1)) : fbm(pos*vec2(0.45,0.85)+vec2(tm*0.28,-tm*0.1));
  carve = smoothstep(q>0.55?0.35:0.38, q>0.55?0.58:0.62, carve);
  float c1=smoothstep(0.62,0.78,n1);float c2=smoothstep(0.64,0.80,n2);
  float clumps=max(c1,c2)*mix(0.35,1.0,carve);
  return pow(clamp(clumps,0.0,1.0), mix(1.15,1.35,q));
}

float sdBox3(vec3 p,vec3 b){vec3 q=abs(p)-b;return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0);}
float rayBoxOffset(vec3 roL,vec3 rdL,vec3 off,vec3 hb){
  vec3 roB=roL-off;vec3 m=1.0/(rdL+1e-6);vec3 t1=(-hb-roB)*m;vec3 t2=(hb-roB)*m;
  vec3 tmi=min(t1,t2);vec3 tma=max(t1,t2);
  float tN=max(max(tmi.x,tmi.y),tmi.z);float tF=min(min(tma.x,tma.y),tma.z);
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
vec3 norToriiPl(vec3 p){float e=0.002;float a=dToriiPl(p);return normalize(vec3(dToriiPl(p+vec3(e,0,0))-a,dToriiPl(p+vec3(0,e,0))-a,dToriiPl(p+vec3(0,0,e))-a));}

vec3 toriiWoodGrain(vec3 p,vec3 nrm){
#ifdef USE_TEXTURE_NOISE
  float g = n(p.xz*28.0);
  float gx = n(p.xz*28.0+vec2(0.008,0.0)) - g;
  float gz = n(p.xz*28.0+vec2(0.0,0.008)) - g;
  return normalize(nrm+vec3(gx*0.06,0.0,gz*0.06));
#else
  vec3 gv=vec3(0.);
  for(int i=0;i<3;i++){float f=1.0+float(i)*0.8;float g=n(p.xz*f*28.0)*0.5+n(p.xz*f*55.0)*0.25;float ge=n((p.xz*f+vec2(0.008,0.0))*28.0)*0.5+n((p.xz*f+vec2(0.008,0.0))*55.0)*0.25;float gn=n((p.xz*f+vec2(0.0,0.008))*28.0)*0.5+n((p.xz*f+vec2(0.0,0.008))*55.0)*0.25;gv+=vec3(ge-g,0.0,gn-g)*f;}
  return normalize(nrm+vec3(gv.x*0.06,0.0,gv.z*0.06));
#endif
}

float rayToriiT(vec3 ro,vec3 rd,vec3 cen,mat3 rot){
  vec3 roL=transpose(rot)*(ro-cen);vec3 rdL=transpose(rot)*rd; float tB=-1.0,tm;
  tm=rayBoxOffset(roL,rdL,vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  return tB;
}
float rayToriiTSc(vec3 ro,vec3 rd,vec3 cen,mat3 rot,float sc){
  vec3 roL=(transpose(rot)*(ro-cen))/sc;vec3 rdL=(transpose(rot)*rd)/sc; float tB=-1.0,tm;
  tm=rayBoxOffset(roL,rdL,vec3(-0.52,0.91,0.0),vec3(0.038,0.91,0.032));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.52,0.91,0.0),vec3(0.038,0.91,0.032));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.85,0.0),vec3(0.86,0.058,0.062));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  tm=rayBoxOffset(roL,rdL,vec3(0.0,1.32,0.0),vec3(0.70,0.046,0.052));if(tm>0.0&&(tB<0.0||tm<tB))tB=tm;
  return tB;
}

float bayerMatrix8x8(vec2 coord){
  ivec2 p = ivec2(mod(coord,8.0));
  const int b[64] = int[64](0,32,8,40,2,34,10,42,48,16,56,24,50,18,58,26,12,44,4,36,14,46,6,38,60,28,52,20,62,30,54,22,3,35,11,43,1,33,9,41,51,19,59,27,49,17,57,25,15,47,7,39,13,45,5,37,63,31,55,23,61,29,53,21);
  return float(b[p.y*8+p.x])/64.0;
}
vec3 applyOrderedDither(vec3 c, vec2 fragCoord){
  float levels=9.0; float pixelSize=2.0;
  vec2 p=floor(fragCoord/pixelSize)*pixelSize;
  float t=bayerMatrix8x8(p);
  float luma=dot(c,vec3(0.299,0.587,0.114));
  float qLuma=floor(luma*levels+t)/levels;
  float scale=qLuma/max(luma,1e-4);
  return mix(c,clamp(c*scale,0.0,1.0),0.72);
}

mat3 rotX(float a){float s=sin(a),c=cos(a);return mat3(1,0,0,0,c,-s,0,s,c);}
mat3 rotY(float a){float s=sin(a),c=cos(a);return mat3(c,0,s,0,1,0,-s,0,c);}
mat3 rotZ(float a){float s=sin(a),c=cos(a);return mat3(c,-s,0,s,c,0,0,0,1);}

float wave(vec2 p,float tm){float w=0.;w+=sin(p.x*0.9+p.y*1.1-tm*1.7)*0.48;w+=sin(p.x*1.4-p.y*0.8+tm*1.2)*0.34;w+=sin(p.x*2.3+p.y*1.9+tm*0.9)*0.22;w+=sin(p.x*3.7-p.y*2.6-tm*1.5)*0.12;w+=sin(p.x*6.4+p.y*3.1-tm*2.3)*0.06;w+=sin(p.x*5.2-tm*2.4)*sin(p.y*2.8+tm*1.7)*0.06;return w;}
vec3 seaNormalFbm(vec2 p,float tm){vec2 e=vec2(0.003,0.0);return normalize(vec3((wave(p-e.xy,tm)-wave(p+e.xy,tm))*WAVE_K/e.x*0.5,1.0,(wave(p-e.yx,tm)-wave(p+e.yx,tm))*WAVE_K/e.x*0.5));}
vec3 seaNormalFbmFine(vec2 p,float tm){vec3 n=vec3(0.);float a=0.5;float f=1.0;for(int i=0;i<4;i++){vec2 e=vec2(0.008/f,0.0);n+=a*vec3((wave((p+e.xy)*f,tm)-wave((p-e.xy)*f,tm)),e.x,(wave((p+e.yx)*f,tm)-wave((p-e.yx)*f,tm)));f*=2.1;a*=0.48;}return normalize(vec3(n.x*0.5,1.0,n.z*0.5));}
float ggxD(float NdotH,float rough){float a=rough*rough;float a2=a*a;float d=(NdotH*NdotH)*(a2-1.0)+1.0;return a2*INV_PI/(d*d);}
float ggxG(float NdotV,float NdotL,float rough){float r=rough+1.0;float k=(r*r)/8.0;return NdotV/(NdotV*(1.0-k)+k)*NdotL/(NdotL*(1.0-k)+k);}
float ggxF0(float NdotH,float NdotV,float NdotL,float f0){float f=f0+(1.0-f0)*pow(1.0-max(NdotH,0.0),5.0);return f*(NdotL*0.2+0.8)+(1.0-NdotL)*0.2;}

void main(){
  vec2 uv=(gl_FragCoord.xy-0.5*r)/r.y;
  vec3 ro=vec3(0.0,1.8,-7.5); vec3 rd=normalize(vec3(uv,1.6)); rd=rotX(0.05)*rd;
  float isSky=step(0.26,rd.y); float time=t*0.85; float D=uiDark;
  vec3 pageBg=vec3(0.090196); vec3 skyPaper=mix(vec3(1.0),pageBg,D);
  vec3 col=skyPaper; float isSea=0.0; vec3 seaOnly=vec3(0.95,0.22,0.30);
  if(isSky<0.5){
    vec2 cubeDrift=vec2(sin(time*0.18)*0.32+sin(time*0.07+1.3)*0.10,cos(time*0.14)*0.18+sin(time*0.05)*0.08);
    /* cubeXZ.y → world Z; larger = farther from camera / deeper into the scene, away from near-shore */
    vec2 cubeXZ=vec2(0.0,13.2)+cubeDrift+cubeOff;
    float wCube = wave(cubeXZ*0.65,time);
    float waterAtCube=wCube*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    float perspZ=clamp((cubeXZ.y-4.0)/12.0,0.0,1.0); float size=mix(1.05,0.45,perspZ); float fl=0.06;
    float cubeShoreZ=SHORE_PARAM+wCube*WAVE_K*0.95;
    float seaDepth=clamp((cubeXZ.y-cubeShoreZ)/3.0,0.0,1.0); float bob=0.7*seaDepth;
    float cubeBaseY=waterAtCube-size*0.35+fl+mix(size*0.55,0.0,seaDepth);
    float bobY=sin(time*0.42+cubeXZ.x*0.35)*0.015*bob+cos(time*0.31-cubeXZ.y*0.26)*0.010*bob;
    vec3 cubePos=vec3(cubeXZ.x,cubeBaseY+bobY,cubeXZ.y);
    float ang=0.785398+sin(time*0.32)*0.12+cos(time*0.21)*0.05;
    float tiltZ=clamp(cubeVel.x*-0.15,-0.25,0.25)*mix(0.2,1.0,seaDepth);
    float tiltX=clamp(cubeVel.y*0.10,-0.20,0.20)*mix(0.2,1.0,seaDepth);
    float waveTilt=bobY*0.8*seaDepth;
    mat3 cubeRot=rotY(ang)*rotX(0.14+sin(time*0.8)*0.06*seaDepth+waveTilt+tiltX)*rotZ(0.09+cos(time*0.6)*0.04*seaDepth+tiltZ);
    float th=-ro.y/rd.y; float seaClip=(rd.y<0.0)?th:1e9; vec3 hit=ro+rd*((th>0.0)?th:1e-3); vec2 p=hit.xz;
    float wSea = wave(p*0.65,time);
    float seaSurf=wSea*WAVE_K;
    float shorePulse=sin(p.x*0.8-time*0.9)*0.06+sin(p.x*2.2+time*1.7)*0.025;
    float shoreZ=SHORE_PARAM+seaSurf*0.95+shorePulse;
    float dist=p.y-shoreZ; isSea=step(0.0,dist);
    float depthTint=clamp(dist*0.42,0.,3.);
    seaOnly=mix(vec3(1.0,0.38,0.48),vec3(0.97,0.22,0.33),smoothstep(0.0,0.7,depthTint));
    seaOnly=mix(seaOnly,vec3(0.82,0.11,0.19),smoothstep(0.7,2.1,depthTint));
    vec3 roC=transpose(cubeRot)*(ro-cubePos); vec3 rdC=transpose(cubeRot)*rd;
    vec3 b=vec3(size); vec3 m=1.0/(rdC+1e-6); vec3 t1=(-b-roC)*m;vec3 t2=(b-roC)*m;
    vec3 tmin2=min(t1,t2);vec3 tmax2=max(t1,t2);
    float tN=max(max(tmin2.x,tmin2.y),tmin2.z); float tF=min(min(tmax2.x,tmax2.y),tmax2.z);
    bool hitCubeV=(tN<tF&&tF>0.0&&tN>0.0&&tN<seaClip);
    float torFarZ=26.2; vec2 tor0XZ=vec2(-10.8,torFarZ); vec2 tor1XZ=vec2(10.8,torFarZ); vec2 tor2XZ=vec2(0.0,35.0);
    float wT0=wave(tor0XZ*0.65,0.0)*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    float wT1=wave(tor1XZ*0.65,0.0)*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    float wT2=wave(tor2XZ*0.65,0.0)*0.72*0.22*(0.55+0.45*WAVE_PARAM);
    vec3 tor0Pos=vec3(tor0XZ.x,wT0,tor0XZ.y); vec3 tor1Pos=vec3(tor1XZ.x,wT1,tor1XZ.y); vec3 tor2Pos=vec3(tor2XZ.x,wT2,tor2XZ.y);
    mat3 tor0Rot=rotY(0.62)*rotX(0.05)*rotZ(0.03); mat3 tor1Rot=rotY(-0.58)*rotX(0.05)*rotZ(-0.03); mat3 tor2Rot=rotY(0.04)*rotX(0.04)*rotZ(0.0);
    float tTor0=rayToriiT(ro,rd,tor0Pos,tor0Rot); float tTor1=rayToriiT(ro,rd,tor1Pos,tor1Rot); float tTor2=rayToriiTSc(ro,rd,tor2Pos,tor2Rot,TOR2_SC);
    float tTor=1e9;int tid=0; if(tTor0>0.0){tTor=tTor0;tid=0;} if(tTor1>0.0&&tTor1<tTor){tTor=tTor1;tid=1;} if(tTor2>0.0&&tTor2<tTor){tTor=tTor2;tid=2;} if(tTor>1e8)tTor=-1.0;
    float tBest=1e9; int hid=-1; if(th>0.0&&rd.y<0.0){tBest=th;hid=0;} if(hitCubeV&&tN<tBest){tBest=tN;hid=1;} if(tTor>=0.0&&tTor<tBest){tBest=tTor;hid=2;} if(hid==-1)isSea=0.0;
    vec3 Lsun=normalize(vec3(0.3,0.8,0.4));
    if(hid==1){
      vec3 ch=ro+rd*tN;vec3 pc=transpose(cubeRot)*(ch-cubePos);vec3 ap=abs(pc);vec3 nrm=vec3(0);
      if(ap.x>ap.y&&ap.x>ap.z)nrm.x=sign(pc.x);else if(ap.y>ap.z)nrm.y=sign(pc.y);else nrm.z=sign(pc.z);
      nrm=normalize(cubeRot*nrm);vec3 base=vec3(0.62,0.10,0.15);
      float top=max(0.0,nrm.y*0.5+0.5);float side=pow(max(0.0,abs(nrm.x)*0.6+abs(nrm.z)*0.4),1.2);float fres=pow(1.0-max(0.0,dot(nrm,-rd)),2.4);
      col=base*(0.58+top*0.42);col+=vec3(1.0,0.26,0.36)*side*0.20;col+=vec3(1.0,0.82,0.86)*fres*0.42;
      float wetLine=ch.y-waterAtCube;float subm=smoothstep(0.04,-0.02,wetLine);col=mix(col,col*0.86+vec3(0.08,0.02,0.03),subm*0.45);col+=exp(-abs(wetLine)*80.0)*0.10*vec3(1.0,0.9,0.92);
      float spec=pow(max(0.,dot(reflect(-Lsun,nrm),-rd)),64.0);col+=spec*0.35*vec3(1.0,0.9,0.95); isSea=0.0;
    }else if(hid==2){
      vec3 ch=ro+rd*tTor;vec3 torCen=tor0Pos;mat3 torR=tor0Rot;float wTw=wT0;
      if(tid==1){torCen=tor1Pos;torR=tor1Rot;wTw=wT1;}else if(tid==2){torCen=tor2Pos;torR=tor2Rot;wTw=wT2;}
      float tsc=(tid==2)?TOR2_SC:1.0;vec3 pl=transpose(torR)*(ch-torCen)/tsc;vec3 nrmL=norToriiPl(pl);vec3 nrm=normalize(torR*nrmL);
      nrm=mix(nrm,toriiWoodGrain(pl,nrm),0.35);
      vec3 base=vec3(0.62,0.12,0.09); float top=max(0.0,nrm.y*0.5+0.5);float side=pow(max(0.0,abs(nrm.x)*0.55+abs(nrm.z)*0.45),1.15);float fres=pow(1.0-max(0.0,dot(nrm,-rd)),2.1);
      col=base*(0.48+top*0.42);col+=vec3(0.78,0.22,0.14)*side*0.28;col+=vec3(0.88,0.42,0.32)*fres*0.36;
      float wetLine=ch.y-wTw;float subm=smoothstep(0.04,-0.02,wetLine);col=mix(col,col*0.82+vec3(0.07,0.02,0.02),subm*0.42);col+=exp(-abs(wetLine)*80.0)*0.09*vec3(0.98,0.55,0.42);
      float spec=pow(max(0.,dot(reflect(-Lsun,nrm),-rd)),56.0);col+=spec*0.28*vec3(1.0,0.72,0.55);
      float rim=pow(max(0.0,1.0-abs(dot(nrm,rd))),3.0)*0.45;col+=rim*vec3(1.0,0.48,0.28)*(0.5+0.5*smoothstep(0.3,0.7,pl.y)); isSea=0.0;
    }else if(hid==0){
      vec3 sand=mix(vec3(1.0),pageBg*1.02,D);sand+=(fbm(p*11.0)-0.5)*0.008;
      float depth=clamp(dist*0.42,0.,3.);vec3 seaShallow=vec3(1.0,0.38,0.48);vec3 seaMid=vec3(0.97,0.22,0.33);vec3 seaDeep=vec3(0.82,0.11,0.19);vec3 sea=mix(seaShallow,seaMid,smoothstep(0.0,0.7,depth));sea=mix(sea,seaDeep,smoothstep(0.7,2.1,depth));
      vec2 luv=p*1.5; float lclA=pow(fbm(luv+vec2(time*0.30,-time*0.08)),9.5); float lclB=pow(fbm(luv*1.9-vec2(time*0.22,time*0.05)),12.0); float lcl=clamp(lclA*0.70+lclB*0.45,0.0,1.0);
      float lclDark=0.45*D; vec3 lclCoral=mix(vec3(1.0,0.66,0.46),vec3(0.20,0.17,0.16),lclDark); vec3 lclWarm=mix(vec3(1.0,0.82,0.66),vec3(0.24,0.20,0.18),lclDark);
      sea+=lcl*0.72*LCL_PARAM*lclCoral*isSea; sea+=pow(fbm(luv*3.3+time*0.18),13.6)*0.20*LCL_PARAM*lclWarm*isSea;
      col=mix(sand,sea,isSea);
      vec2 seaL=p*vec2(0.036,0.028)+vec2(time*0.041,-time*0.017); vec2 seaC0=p*vec2(0.071,0.056)+vec2(time*0.055,-time*0.02); vec2 seaC1=p*vec2(0.065,0.051)*0.92+vec2(-time*0.048,time*0.015); vec2 seaS=p*vec2(0.118,0.092)+vec2(-time*0.068,time*0.044); vec2 seaT=p*vec2(0.095,0.074)*1.1+vec2(time*0.031,-time*0.052);
      float sdL=cloudDensity(seaL,time*0.88,cloudQ); float sdSea0=cloudDensity(seaC0,time,cloudQ); float sdSea1=cloudDensity(seaC1,time+4.5,cloudQ); float sdS=cloudQ>0.42?cloudDensity(seaS,time+2.8,cloudQ):0.0; float sdT=cloudQ>0.5?cloudDensity(seaT,time+6.5,cloudQ):0.0;
      float cMix=max(max(sdSea0,sdSea1),max(max(sdL*0.95,sdS),sdT*0.9)); float openW=smoothstep(0.08,1.4,dist*0.42)*isSea; float cMix2=cMix*cMix; float cSh=smoothstep(0.42,0.92,cMix)*(0.42+0.58*cMix2)*openW; float cRf=max(smoothstep(0.32,0.62,cMix)*(1.0-cSh*0.75),0.0)*openW;
      col*=mix(vec3(1.0),vec3(0.58,0.60,0.74),cSh*0.62); col+=cRf*vec3(0.06+0.04*cMix,0.065+0.035*cMix,0.085+0.04*cMix);
      float d=dist;float absD=abs(d); float shoreBand=exp(-d*d*18.0);shoreBand*=smoothstep(-0.35,0.20,d+0.08); float foamFlow=0.55+0.45*sin((p.x*3.8-time*1.9)+fbm(p*2.4-time*0.35)*3.0); float foamNoise=smoothstep(0.25,0.85,fbm(p*4.2+vec2(time*0.55,-time*0.42))); shoreBand*=mix(0.8,1.5,foamNoise)*foamFlow; float washFoam=smoothstep(0.0,0.22,d)*smoothstep(0.55,0.12,d)*fbm(vec2(p.x*5.0-time*1.2,p.y*8.0+time*0.6))*1.4; shoreBand=max(shoreBand,washFoam*isSea);
      vec2 fp=p*vec2(2.3,2.8)+vec2(time*0.24,-time*0.31)+vec2(fbm(p*1.8+time*0.2)*0.6,0.);vec2 ip=floor(fp);vec2 f=fract(fp);float d1=10.,d2=10.; for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){vec2 o2=vec2(float(x),float(y));vec2 h2=fract(sin((ip+o2)*mat2(127.1,311.7,269.5,183.3))*43758.5);h2=0.5+0.42*sin(time*0.22+h2*6.2831);float dd=length(o2+h2-f);if(dd<d1){d2=d1;d1=dd;}else if(dd<d2){d2=dd;}}}
      float cells=smoothstep(0.16,0.0,d2-d1);float foam=cells*shoreBand*3.2*FOAM_PARAM;float trailing=smoothstep(0.25,-0.04,d)*smoothstep(-0.28,0.02,d);col=mix(col,vec3(1.0,0.96,0.97),foam*0.62);col=mix(col,vec3(1.0),foam*0.98);col=mix(col,vec3(1.0,0.95,0.97),trailing*cells*0.35*FOAM_PARAM);col=mix(col,vec3(1.0),smoothstep(0.05,0.0,absD)*0.85*isSea*FOAM_PARAM);
      float toCube=length(p-cubeXZ);float wake=1.0-smoothstep(0.0,size*2.2,toCube);wake*=isSea;float ring=exp(-pow(toCube-size*1.15,2.0)*18.0); float moveAmt=clamp(length(cubeVel)*0.12,0.0,1.0); float rippleReach=mix(3.0,5.8,moveAmt)*mix(0.55,1.0,seaDepth); float rippleFreq=mix(10.5,14.0,moveAmt); float rippleSpeed=mix(2.8,4.8,moveAmt); float rippleEnvelope=(1.0-smoothstep(0.0,rippleReach,toCube))*exp(-toCube*0.42); float baseRing=0.5+0.5*sin(toCube*rippleFreq-time*rippleSpeed); float ringMask=smoothstep(0.50,0.80,baseRing); float broken=0.65+0.35*fbm(vec2(toCube*3.8,time*1.0)+p*2.0); float ripple=ringMask*broken*rippleEnvelope*isSea;
      float toTor0=length(p-tor0XZ); float toTor1=length(p-tor1XZ); float toTor2=length(p-tor2XZ); float reM=mix(3.4,5.8,moveAmt)*mix(0.55,1.0,seaDepth); float fqM=mix(9.5,13.0,moveAmt); float spM=mix(2.5,4.2,moveAmt); float envM0=(1.0-smoothstep(0.0,reM,toTor0))*exp(-toTor0*0.38); float envM1=(1.0-smoothstep(0.0,reM,toTor1))*exp(-toTor1*0.38); float envM2=(1.0-smoothstep(0.0,reM,toTor2))*exp(-toTor2*0.38); float brM0=0.5+0.5*sin(toTor0*fqM-time*spM); float brM1=0.5+0.5*sin(toTor1*fqM-time*spM); float brM2=0.5+0.5*sin(toTor2*fqM-time*spM); float rkM0=smoothstep(0.48,0.78,brM0)*(0.65+0.35*fbm(vec2(toTor0*3.6,time*0.95)+p*1.8)); float rkM1=smoothstep(0.48,0.78,brM1)*(0.65+0.35*fbm(vec2(toTor1*3.6,time*0.95)+p*1.8)); float rkM2=smoothstep(0.48,0.78,brM2)*(0.65+0.35*fbm(vec2(toTor2*3.6,time*0.95)+p*1.8)); float rippleM=max(max(rkM0*envM0,rkM1*envM1),rkM2*envM2)*isSea; ripple=max(ripple,rippleM); col=mix(col,col*0.90,wake*0.24); col=mix(col,vec3(1.0,0.97,0.98),wake*0.22+ring*0.12+ripple*0.30); col+=vec3(1.0,0.88,0.92)*ripple*0.12;
      float reflC=smoothstep(size*1.8,0.0,toCube)*isSea*0.5; float reflT0=smoothstep(8.8,0.0,toTor0)*isSea; float reflT1=smoothstep(8.8,0.0,toTor1)*isSea; float reflT2=smoothstep(8.8,0.0,toTor2)*isSea; float reflTor=max(max(reflT0,reflT1),reflT2)*0.88; float refl=max(reflC,reflTor); float wShore=smoothstep(0.0,0.28,-dist); float wTor=max(max(reflT0,reflT1),reflT2); float reflW=max(wShore*isSea,wTor); col=mix(col,vec3(0.55,0.08,0.13),refl*reflW);
      vec3 seaN=seaNormalFbm(p,time); vec3 Hsun=Lsun+(-rd);float hLen=length(Hsun);vec3 halfVec=hLen>1e-4?Hsun/hLen:vec3(0.0,1.0,0.0); float NdotH=max(0.0,dot(seaN,halfVec));float NdotV=max(0.0,dot(seaN,-rd));float NdotL=max(0.0,dot(seaN,Lsun)); float rough=0.18+0.12*fbm(p*2.2+time*0.15);float f0=0.02; float Dggx=ggxD(NdotH,rough);float Gggx=ggxG(NdotV,NdotL,rough);float Fggx=ggxF0(NdotH,NdotV,NdotL,f0); float specGlint=Dggx*Gggx*Fggx*0.42*isSea*smoothstep(0.0,0.35,dist); col+=specGlint*vec3(1.0,0.92,0.88);
      if(cloudQ>0.385){
        vec3 seaNh2=seaNormalFbmFine(p*1.8,time);float NdotH2=max(0.0,dot(seaNh2,halfVec)); float D2=ggxD(NdotH2,rough*0.65);float G2=ggxG(NdotV,NdotL,rough*0.65); float F2=ggxF0(NdotH2,NdotV,NdotL,f0);float specGlint2=D2*G2*F2*0.28*isSea*smoothstep(0.0,0.5,dist); col+=specGlint2*vec3(1.0,0.85,0.78);
      }
    }
  }
  float cloudH=-uv.y; float cloudBand=smoothstep(0.0,0.018,cloudH)*smoothstep(0.20,0.055,cloudH); float cq=clamp(cloudQ,0.2,1.0); vec2 scBase=vec2(uv.x*7.5,cloudH*22.0);
  vec2 cd0UV=scBase+vec2(time*0.055,-time*0.02); vec2 cd1UV=scBase*0.92+vec2(-time*0.048,time*0.015);
  float sd0=cloudDensity(cd0UV,time,cq); float sd1=cloudDensity(cd1UV,time+4.5,cq);
  float sd2=0.0,sd3=0.0,sd4=0.0,sd5=0.0,sd6=0.0;
  if(cq>0.38){ vec2 cd2UV=scBase*0.84+vec2(time*0.034,time*0.011); vec2 cd3UV=scBase*1.18+vec2(-time*0.062,time*0.021); sd2=cloudDensity(cd2UV,time+9.0,cq); sd3=cloudDensity(cd3UV,time+6.2,cq); }
  if(cq>0.52){ vec2 cd4UV=scBase*0.48+vec2(time*0.038,-time*0.029); vec2 cd5UV=scBase*1.42+vec2(-time*0.071,time*0.018); vec2 cd6UV=scBase*0.72+vec2(time*0.062,-time*0.041); sd4=cloudDensity(cd4UV,time+1.7,cq); sd5=cloudDensity(cd5UV,time+8.3,cq); sd6=cloudDensity(cd6UV,time+3.4,cq); }
  float sa0=smoothstep(0.48,0.82,sd0); float sa1=smoothstep(0.50,0.84,sd1); float sa2=smoothstep(0.52,0.86,sd2); float sa3=smoothstep(0.44,0.78,sd3); float sa4=smoothstep(0.44,0.78,sd4); float sa5=smoothstep(0.38,0.74,sd5); float sa6=smoothstep(0.46,0.80,sd6);
  float heightGrad=smoothstep(0.16,0.025,cloudH); vec3 seaTint=mix(col,seaOnly,0.0); float lowerW=(1.0-heightGrad); vec3 cloudBot=vec3(0.90,0.88,0.91); vec3 botCol=mix(cloudBot,seaTint,isSea*0.20*lowerW); vec3 cloudTop=mix(vec3(1.0),seaTint,isSea*0.06); vec3 cc0=mix(botCol,cloudTop,heightGrad); vec3 cc1=mix(botCol*0.97,cloudTop*0.98,heightGrad)*(1.0-sa0*0.20); vec3 cc2=mix(botCol*0.94,cloudTop*0.96,heightGrad)*(1.0-sa0*0.16)*(1.0-sa1*0.14); float cMask=cloudBand*mix(0.5,1.0,cq); float cw=mix(0.62,1.0,cq); col=mix(col,cc0,sa0*cMask*0.72*cw); col=mix(col,cc1,sa1*(1.0-sa0*0.55)*cMask*0.58*cw); col=mix(col,cc2,sa2*(1.0-sa0*0.45)*(1.0-sa1*0.35)*cMask*0.48*cw); vec3 cc3=mix(botCol*0.93,cloudTop*0.95,heightGrad)*(1.0-sa0*0.12)*(1.0-sa2*0.18); col=mix(col,cc3,sa3*(1.0-sa0*0.38)*(1.0-sa1*0.28)*cMask*0.52*cw); vec3 cc4=mix(botCol*0.96,cloudTop*0.99,heightGrad)*(1.0-sa4*0.18); vec3 cc5=mix(botCol*0.91,cloudTop*0.94,heightGrad)*(1.0-sa5*0.22); vec3 cc6=mix(botCol*0.94,cloudTop*0.97,heightGrad)*(1.0-sa6*0.16); col=mix(col,cc4,sa4*(1.0-sa0*0.42)*(1.0-sa3*0.35)*cMask*0.46*cw); col=mix(col,cc5,sa5*(1.0-sa4*0.50)*(1.0-sa1*0.30)*cMask*0.40*cw); col=mix(col,cc6,sa6*(1.0-sa5*0.45)*(1.0-sa2*0.28)*cMask*0.36*cw); float cCore=smoothstep(0.82,0.97,sd0)*cMask*mix(0.35,1.0,cq); vec3 coreCol=mix(vec3(1.0),seaTint,isSea*0.04); col=mix(col,coreCol,cCore*0.62); col+=seaTint*sa0*cMask*isSea*0.035*lowerW; col+=seaTint*sa3*cMask*isSea*0.028*lowerW; col+=seaTint*(sa4*0.028+sa5*0.024+sa6*0.022)*cMask*isSea*lowerW;
  float ditherAmt=mix(0.32,1.0,isSea)*mix(1.0,0.38,D*(1.0-isSea)); ditherAmt*=1.0-D*isSky;
  if(ditherAmt>0.002 && cloudQ>0.36){
    col=clamp(mix(col,applyOrderedDither(col,gl_FragCoord.xy),ditherAmt),0.0,1.0);
  }else{
    col=clamp(col,0.0,1.0);
  }
  float skyA=smoothstep(0.99,0.34,rd.y); float outASky=mix(1.0,skyA,isSky); float outA=mix(outASky,1.0,D); o=vec4(col,outA);
}