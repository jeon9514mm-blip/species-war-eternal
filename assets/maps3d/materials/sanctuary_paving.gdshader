shader_type spatial;
uniform sampler2D carving : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D stone_color : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D stone_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float combat_readability : hint_range(0.0,1.0)=0.;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world.xz-vec2(16.,10.);
 float radius=length(p);
 vec3 stone=texture(stone_color,world.xz*.14).rgb*vec3(.67,.78,.73);
 float seam=1.-smoothstep(.015,.045,abs(sin(radius*1.3)));
 float moss=smoothstep(.72,.94,sin(p.x*.53)*sin(p.y*.41))*.32;
 stone=mix(stone,vec3(.11,.17,.07),moss);
 stone*=1.-seam*.16;
 vec2 uv=p/18.+.5;
 // Preserve nonzero derivatives at the clamped border (software Vulkan anisotropy).
 vec3 glyph=vec3(0.);
 vec2 du=dFdx(uv),dv=dFdy(uv);
 if(radius<9.1){glyph=textureGrad(carving,clamp(uv,vec2(0.),vec2(1.)),du,dv).rgb;}
 float inside=1.-smoothstep(8.8,9.1,radius);
 float blue=smoothstep(.06,.22,max(0.,glyph.b-glyph.r*1.15))*inside;
 ALBEDO=mix(stone,glyph*.58,inside*.85);
 ALBEDO*=mix(1.,.82,combat_readability*inside);
 float courtyard=1.-smoothstep(.99,1.10,length(p/vec2(23.,18.)));
 ALBEDO=mix(vec3(.025,.048,.032),ALBEDO,courtyard);
 EMISSION=vec3(.18,.84,.91)*blue*mix(1.2,.25,combat_readability);
 ROUGHNESS=.86;SPECULAR=.22;
 NORMAL_MAP=texture(stone_normal,world.xz*.14).rgb;NORMAL_MAP_DEPTH=.32;
}
