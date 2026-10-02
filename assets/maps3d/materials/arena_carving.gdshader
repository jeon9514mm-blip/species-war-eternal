shader_type spatial;
uniform sampler2D carving : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D border_stone : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 uv=(world.xz-vec2(16,10))/39.2+vec2(.5);
 vec3 color=texture(carving,clamp(uv,vec2(0.),vec2(1.))).rgb;
 bool outside=length(world.xz-vec2(16,10))>19.6;
 if(outside){color=texture(border_stone,world.xz*.22).rgb*.55;}
 float blue=max(0.,color.b-color.r*1.15);
 ALBEDO=color*.9;ROUGHNESS=.73;SPECULAR=.35;
 EMISSION=vec3(.12,.62,1.)*smoothstep(.065,.22,blue)*.9*float(!outside);
 // A tiny material relief makes engraved edges respond to the real lighting.
 vec2 texel=vec2(1./1536.);
 float dx=dot(texture(carving,uv+vec2(texel.x,0)).rgb-texture(carving,uv-vec2(texel.x,0)).rgb,vec3(.333));
 float dy=dot(texture(carving,uv+vec2(0,texel.y)).rgb-texture(carving,uv-vec2(0,texel.y)).rgb,vec3(.333));
 NORMAL_MAP=normalize(vec3(-dx*.6,-dy*.6,1.))*.5+.5;NORMAL_MAP_DEPTH=.32;
}
