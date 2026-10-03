shader_type spatial;
uniform sampler2D rock_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color=vec4(1.0);
uniform float texture_scale=.65;
uniform float frost_amount : hint_range(0.0,1.0)=0.;
uniform float moss_amount : hint_range(0.0,1.0)=0.;
uniform float strata_amount : hint_range(0.0,1.0)=0.;
varying vec3 world;
varying vec3 world_normal;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 w=pow(abs(world_normal),vec3(5));w/=w.x+w.y+w.z;
 vec3 c=texture(rock_texture,world.zy*texture_scale).rgb*w.x+texture(rock_texture,world.xz*texture_scale).rgb*w.y+texture(rock_texture,world.xy*texture_scale).rgb*w.z;
 float grain=dot(c,vec3(.299,.587,.114));
 float strata=sin(world.y*7.+sin(world.x*.35+world.z*.27)*1.6);
 c*=mix(1.,.83+strata*.16,strata_amount);
 float top=smoothstep(.25,.85,world_normal.y);
 ALBEDO=c*tint.rgb;
 ALBEDO=mix(ALBEDO,vec3(.40,.57,.66),frost_amount*top*smoothstep(.12,.58,grain));
 ALBEDO=mix(ALBEDO,vec3(.085,.19,.055)*(0.7+grain),moss_amount*top*smoothstep(.1,.50,grain));
 ROUGHNESS=.83+top*.12;
 // Surface-gradient bump adds small relief without changing collision geometry.
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
 float det=dot(dx,r1);
 if(abs(det)>.000001){NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(grain)*r1+dFdy(grain)*r2)*.12);}
}
