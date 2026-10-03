shader_type spatial;
uniform sampler2D meadow_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D dirt_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D dirt_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform int theme=0;
uniform float combat_readability : hint_range(0.0,1.0) = 0.0;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 if(theme==1 && length((world.xz-vec2(16.,10.))/vec2(25.,19.))>1.){discard;}
 float n=noise(world.xz*.28)*.6+noise(world.xz*1.2)*.3+noise(world.xz*5.)*.1;
 vec3 turf=texture(meadow_texture,world.xz*.19).rgb;
 vec3 dirt=texture(dirt_texture,world.xz*(theme==1?.075:.27)).rgb;
 float path=1.-smoothstep(.25,2.1,abs(world.z-(14.-world.x*.13))+(n-.5)*4.);
 float patches=smoothstep(.48,.72,n);
 vec3 c=mix(turf*vec3(.80,1.07,.7),dirt,max(path*.6,patches*.7));
 if(theme==1){c=dirt*vec3(.88,.60,.45);}
 if(theme==2){c=dirt*vec3(.69,.86,.95);}
 float edge=max(max(-world.x,world.x-32.),max(-world.z,world.z-20.));
 c*=mix(1.,.70,smoothstep(-1.,4.,edge));
 ALBEDO=c*(.88+n*.22);ROUGHNESS=.86+n*.12;
 NORMAL_MAP=texture(dirt_normal,world.xz*(theme==1?.075:.27)).rgb;NORMAL_MAP_DEPTH=.30;
 ALBEDO*=mix(1.,.82,combat_readability*(1.-smoothstep(11.,19.,length(world.xz-vec2(16,10)))));
}
