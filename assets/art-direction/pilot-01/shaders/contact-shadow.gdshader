shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 shadow_color : source_color = vec4(0.075, 0.095, 0.06, 0.34);
void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float feather = 1.0 - smoothstep(0.18, 1.0, radius);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * feather * feather;
}
