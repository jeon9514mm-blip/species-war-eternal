shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

// This shades the existing GPU-skinned plane; it does not replace its skeleton.
// All taps stay inside the one bind-pose atlas region, including outline taps.
uniform sampler2D source_texture : source_color, filter_linear, repeat_disable;
uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 atlas_texel = vec2(0.001);
uniform vec4 actor_tint : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.10, 0.16, 0.19, 0.76);
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.73, 1.0);
uniform float outline_px : hint_range(0.0, 2.0) = 1.05;
uniform float rim_strength : hint_range(0.0, 0.5) = 0.18;
uniform float facing_sign = 1.0;

vec4 atlas_sample(vec2 uv) {
	vec2 lo = atlas_rect.xy + atlas_texel * 0.5;
	vec2 hi = atlas_rect.xy + atlas_rect.zw - atlas_texel * 0.5;
	float inside = step(lo.x, uv.x) * step(lo.y, uv.y) * step(uv.x, hi.x) * step(uv.y, hi.y);
	vec4 value = texture(source_texture, clamp(uv, lo, hi));
	value.a *= inside;
	return value;
}

void fragment() {
	vec4 base = atlas_sample(UV);
	// Derivatives express the contour width in rendered pixels, not atlas pixels.
	vec2 radius = clamp(fwidth(UV) * outline_px, atlas_texel * 0.35, atlas_texel * 3.0);
	float dilation = base.a;
	dilation = max(dilation, atlas_sample(UV + vec2(radius.x, 0.0)).a);
	dilation = max(dilation, atlas_sample(UV - vec2(radius.x, 0.0)).a);
	dilation = max(dilation, atlas_sample(UV + vec2(0.0, radius.y)).a);
	dilation = max(dilation, atlas_sample(UV - vec2(0.0, radius.y)).a);
	dilation = max(dilation, atlas_sample(UV + radius * 0.7071).a);
	dilation = max(dilation, atlas_sample(UV - radius * 0.7071).a);
	dilation = max(dilation, atlas_sample(UV + vec2(radius.x, -radius.y) * 0.7071).a);
	dilation = max(dilation, atlas_sample(UV + vec2(-radius.x, radius.y) * 0.7071).a);
	float contour = max(0.0, dilation - base.a) * outline_color.a;
	float opacity = base.a + contour * (1.0 - base.a);
	// Planar normals cannot describe hair contours. An alpha-edge accent instead
	// follows the painted silhouette and keeps the warm light at screen upper left.
	float toward_light = atlas_sample(UV + radius * vec2(-facing_sign, -1.0)).a;
	float rim = max(0.0, base.a - toward_light) * rim_strength;
	vec3 painted = min(base.rgb + rim_color.rgb * rim, vec3(1.0));
	vec3 combined = mix(outline_color.rgb, painted, base.a / max(opacity, 0.0001));
	ALBEDO = combined * actor_tint.rgb;
	ALPHA = opacity * actor_tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.025;
}
