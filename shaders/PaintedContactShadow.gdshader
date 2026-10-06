shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Soft footprint on the painted floor; has no simulation or lighting dependency.
void fragment() {
    float radius = length((UV - vec2(0.5)) * vec2(1.0, 1.25));
    float falloff = 1.0 - smoothstep(0.06, 0.5, radius);
    ALBEDO = vec3(0.055, 0.075, 0.06);
    ALPHA = falloff * falloff * 0.25;
}
