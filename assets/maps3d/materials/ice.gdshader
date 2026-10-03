shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ice_color : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D ice_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D ice_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 ice_tint : source_color=vec4(.22,.55,.70,1.);
varying vec3 world;
varying vec3 wn;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 w=pow(abs(wn),vec3(4));w/=w.x+w.y+w.z;
 vec3 frost=texture(ice_color,world.zy*.24).rgb*w.x+texture(ice_color,world.xz*.24).rgb*w.y+texture(ice_color,world.xy*.24).rgb*w.z;
 float rim=pow(1.-max(0.,dot(normalize(NORMAL),normalize(VIEW))),3.);
 // Triplanar normal detail follows each face of a crystal, including scaled instances.
 vec3 nx=texture(ice_normal,world.zy*.24).xyz*2.-1.;
 vec3 ny=texture(ice_normal,world.xz*.24).xyz*2.-1.;
 vec3 nz=texture(ice_normal,world.xy*.24).xyz*2.-1.;
 vec3 detail=normalize(vec3(nx.z*sign(wn.x),nx.y,nx.x)*w.x+vec3(ny.x,ny.z*sign(wn.y),ny.y)*w.y+vec3(nz.x,nz.y,nz.z*sign(wn.z))*w.z);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(wn,detail,.32)),0.)).xyz);
 float rough=texture(ice_roughness,world.zy*.24).r*w.x+texture(ice_roughness,world.xz*.24).r*w.y+texture(ice_roughness,world.xy*.24).r*w.z;
 float snow=smoothstep(.28,.88,wn.y)*smoothstep(.22,.68,frost.r);
 float cracks=smoothstep(.44,.80,frost.r);
 ALBEDO=mix(ice_tint.rgb*vec3(.36,.63,.85),frost*vec3(.55,.78,.92),.36);
 ALBEDO=mix(ALBEDO,vec3(.55,.76,.85),snow*.65);
 ROUGHNESS=mix(.13+rough*.22,.65,snow);METALLIC=0.;SPECULAR=.58;RIM=.22;RIM_TINT=.35;
 EMISSION=ice_tint.rgb*(.065+rim*.27+cracks*.12)*(1.-snow*.7);
}
