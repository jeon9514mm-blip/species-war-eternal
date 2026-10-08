shader_type canvas_item;
render_mode blend_add;
uniform float phase=0.0;
uniform float identity=1.0;
uniform float symmetry=6.0;
uniform vec4 core_color:source_color=vec4(1.0);
uniform float glow=0.9;
uniform float distortion=0.05;
uniform vec4 uv_region=vec4(0.0,0.0,1.0,1.0);
void fragment(){
	vec2 centered=(UV-uv_region.xy)/uv_region.zw-vec2(.5);
	float angle=atan(centered.y,centered.x);
	float ripple=sin(angle*symmetry+phase*9.0+identity*.37)*sin(phase*3.14159);
	vec2 offset=centered*ripple*distortion*.15*uv_region.zw;
	vec4 source=texture(TEXTURE,UV+offset);
	vec2 px=TEXTURE_PIXEL_SIZE*1.5;
	float halo=(texture(TEXTURE,UV+offset+vec2(px.x,0)).a+texture(TEXTURE,UV+offset-vec2(px.x,0)).a+texture(TEXTURE,UV+offset+vec2(0,px.y)).a+texture(TEXTURE,UV+offset-vec2(0,px.y)).a)*.25;
	float reveal=smoothstep(0.0,.18,phase)*(1.0-smoothstep(.65,1.0,phase));
	float chroma=(texture(TEXTURE,UV+vec2(.003,0)).a-texture(TEXTURE,UV-vec2(.003,0)).a)*.05;
	vec3 tint=mix(COLOR.rgb,core_color.rgb,source.a*.5);
	COLOR=vec4(tint*(source.a+halo*glow)+vec3(chroma,0,-chroma),max(source.a,halo*.5)*COLOR.a*reveal);
}
