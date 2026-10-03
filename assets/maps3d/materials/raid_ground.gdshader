shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D detail_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D carving : source_color, filter_linear_mipmap_anisotropic;
uniform int theme = 0; // 0 woodland, 1 canyon, 2 lunar sanctuary, 3 ice
uniform float combat_readability : hint_range(0.,1.) = 0.;
varying vec3 world;
vec2 random2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
vec3 cells(vec2 p){
 vec2 i=floor(p),f=fract(p);float a=8.,b=8.;vec2 chosen=vec2(0.);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y));vec2 r=g+.16+random2(i+g)*.68-f;float d=dot(r,r);
  if(d<a){b=a;a=d;chosen=i+g;}else if(d<b){b=d;}
 }}
 return vec3(sqrt(b)-sqrt(a),random2(chosen).x,sqrt(a));
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world.xz-vec2(16.,10.);
 float radial=length(p/vec2(16.8,10.8));
 vec2 cell_position=world.xz*(theme==1?1.25:.65);
 if(theme==1){cell_position+=vec2(sin(world.z*1.3),sin(world.x*1.7))*.16;}
 vec3 v=cells(cell_position);
 float seam=1.-smoothstep(.008,.025,v.x);
 float bevel=smoothstep(.008,.040,v.x);
 vec3 detail=texture(detail_color,world.xz*.23).rgb;
 float grain=dot(detail,vec3(.299,.587,.114));
 float relief=1.;
 vec3 base=vec3(.24,.30,.26);
 if(theme==1){base=vec3(.34,.205,.12)*(.93+v.y*.055);}
 if(theme==2){base=mix(vec3(.16,.21,.26),vec3(.33,.39,.43),v.y);}
 if(theme==3){base=mix(vec3(.14,.30,.39),vec3(.33,.52,.57),v.y);}
 base*=.76+grain*.55;
 base*=mix(.25,1.,bevel);
 // Larger quiet patches let the player distinguish the orange/red attack overlay.
 if(theme==0){
  float patches=smoothstep(.28,.61,sin(p.x*.28+sin(p.y*.37))*sin(p.y*.21)+.35);
  vec3 grass=mix(vec3(.21,.31,.12),vec3(.32,.40,.17),grain);
  float paving=smoothstep(.65,.92,radial)*.8;
  vec3 turf=grass*.70+detail*.20;
  vec3 soil=vec3(.13,.10,.065)*(.8+grain*.45);
  vec3 clearing=mix(turf,soil,patches*.26);
  base=mix(clearing,base,paving*.65);
  seam*=paving*.55;relief=paving*.25;
 }
 float ring=1.-smoothstep(.025,.09,abs(length(p)-7.4));
 float ring2=1.-smoothstep(.025,.08,abs(length(p)-7.65));
 float rays=pow(max(0.,cos(atan(p.y,p.x)*12.)),18.);
 vec3 rune_color=theme==2?vec3(.25,.63,.78):theme==3?vec3(.32,.67,.78):vec3(.45,.38,.23);
 float glyph=(ring*.22+ring2*.10)*rays;
 if(theme==0){glyph=0.;}
 base=mix(base,rune_color,glyph);
 base*=mix(1.,.88,combat_readability*(1.-smoothstep(.6,1.,radial)));
 if(theme==2){base=mix(vec3(.005,.016,.013),base,1.-smoothstep(1.0,1.12,radial));}
 float ink=0.;
 vec2 glyph_uv=p/16.+.5;vec2 du=dFdx(glyph_uv),dv=dFdy(glyph_uv);
 if(theme==2 && length(p)<8.){
  vec3 carving_color=textureGrad(carving,clamp(glyph_uv,vec2(0.),vec2(1.)),du,dv).rgb;
  ink=smoothstep(.04,.22,max(0.,carving_color.b-carving_color.r*1.1))*(1.-smoothstep(7.8,8.,length(p)));
 }
 ALBEDO=mix(base,vec3(.26,.42,.53),ink*.40);
 EMISSION=rune_color*glyph*(theme==2?.48:.12)*mix(1.,.35,combat_readability);
 EMISSION+=vec3(.19,.48,.72)*ink*.65*mix(1.,.22,combat_readability);
 ROUGHNESS=theme==3?.52:.91;SPECULAR=.22;
 NORMAL_MAP=texture(detail_normal,world.xz*.23).rgb;NORMAL_MAP_DEPTH=theme==0?.16:.26;
 // Relief at the stone edge, without displacing the playable floor.
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
 float det=dot(dx,r1);float h=bevel*.012*relief+grain*.005;
 if(abs(det)>.000001){NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(h)*r1+dFdy(h)*r2));}
}
