shader_type spatial;
uniform sampler2D carving : source_color,filter_linear_mipmap_anisotropic;
void fragment(){vec3 c=texture(carving,UV).rgb;ALBEDO=c;ROUGHNESS=.67;float b=max(0.,c.b-c.r*1.25);EMISSION=vec3(.1,.6,1.)*smoothstep(.09,.3,b)*.65;}
