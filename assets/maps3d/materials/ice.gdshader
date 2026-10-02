shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ice_color : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D ice_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 ice_tint : source_color=vec4(.22,.55,.70,1.);
varying vec3 world;
varying vec3 wn;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 w=pow(abs(wn),vec3(4));w/=w.x+w.y+w.z;
 vec3 frost=texture(ice_color,world.zy*.24).rgb*w.x+texture(ice_color,world.xz*.24).rgb*w.y+texture(ice_color,world.xy*.24).rgb*w.z;
 float rim=pow(1.-max(0.,dot(normalize(NORMAL),normalize(VIEW))),3.);
 ALBEDO=mix(ice_tint.rgb,frost*vec3(.63,.84,1.),.48);
 ROUGHNESS=.20+frost.r*.27;METALLIC=.15;SPECULAR=.72;RIM=.4;RIM_TINT=.5;
 EMISSION=ice_tint.rgb*(.02+rim*.09);
}
