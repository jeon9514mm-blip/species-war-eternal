shader_type spatial;
render_mode diffuse_burley;
uniform vec4 water_color : source_color = vec4(.055,.34,.36,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(VERTEX.x*3.0+TIME)*.018;}
void fragment(){float ripple=sin(world.x*6.0+world.z*4.0+TIME*1.3)*sin(world.x*3.0-world.z*7.0+TIME*.7);ALBEDO=water_color.rgb+vec3(.06,.11,.1)*pow(max(0.0,ripple),8.0);ROUGHNESS=.22;METALLIC=.30;}
