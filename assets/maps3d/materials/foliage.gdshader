shader_type spatial;
render_mode cull_disabled,diffuse_burley;
uniform vec4 foliage_tint : source_color=vec4(1.0);
varying vec4 tint;
void vertex(){tint=COLOR;vec3 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.x+=sin(TIME*.9+world.x*.7+world.z*.4)*.035*smoothstep(1.,6.,VERTEX.y);}
void fragment(){ALBEDO=pow(tint.rgb,vec3(2.2))*foliage_tint.rgb;ROUGHNESS=.8;BACKLIGHT=ALBEDO*.18;}
