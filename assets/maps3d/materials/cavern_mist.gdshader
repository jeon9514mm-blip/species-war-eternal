shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
uniform vec4 mist_color : source_color=vec4(.12,.24,.39,.23);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){float n=noise(UV*12.+vec2(TIME*.008,0))*.6+noise(UV*29.-TIME*.006)*.4;float edge=smoothstep(0.,.15,UV.x)*smoothstep(0.,.15,UV.y)*smoothstep(1.,.85,UV.x)*smoothstep(1.,.85,UV.y);ALBEDO=mist_color.rgb;ALPHA=mist_color.a*(.5+n)*edge;}
