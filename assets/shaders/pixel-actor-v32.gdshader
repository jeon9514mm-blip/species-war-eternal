shader_type canvas_item;
render_mode unshaded;

// A restrained SNES-like channel ramp. Sampling remains on the original
// texture UV; no pixel-grid remap can leak adjacent AtlasTexture cells.
uniform float color_steps : hint_range(8.0, 64.0) = 31.0;
uniform float contrast : hint_range(0.8, 1.3) = 1.045;
uniform float saturation : hint_range(0.8, 1.3) = 1.035;
uniform float dither_strength : hint_range(0.0, 0.25) = 0.10;
// Optional source-fringe cleanup for generated monster sheets. Heroes keep
// the default 0.0. Test source alpha before modulation so death fades survive.
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;
varying vec4 actor_tint;

void vertex() {
	// Apply node modulation once, after the palette treatment. This preserves
	// hit flashes, death fades, parent modulation and source alpha exactly.
	actor_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a < alpha_cutoff) {
		source.a = 0.0;
	}
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 ramp = mix(vec3(luminance), source.rgb, saturation);
	ramp = clamp((ramp - vec3(0.5)) * contrast + vec3(0.5), vec3(0.0), vec3(1.0));
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float checker = mod(pixel.x + pixel.y, 2.0) - 0.5;
	ramp = floor(clamp(ramp + checker * dither_strength / color_steps,
		vec3(0.0), vec3(1.0)) * color_steps + vec3(0.5)) / color_steps;
	COLOR = vec4(ramp, source.a) * actor_tint;
}
