shader_type spatial;
uniform sampler2D rock_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color=vec4(1.0);
uniform float texture_scale=.65;
varying vec3 world;
varying vec3 world_normal;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){vec3 w=pow(abs(world_normal),vec3(5));w/=w.x+w.y+w.z;vec3 c=texture(rock_texture,world.zy*texture_scale).rgb*w.x+texture(rock_texture,world.xz*texture_scale).rgb*w.y+texture(rock_texture,world.xy*texture_scale).rgb*w.z;ALBEDO=c*tint.rgb;ROUGHNESS=.91;}
