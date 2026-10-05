shader_type spatial;
render_mode cull_disabled, depth_draw_never;

// Adapted from the shared patch: measure real camera distance and retain
// existing mesh colour, instead of drawing an opaque green plane.
uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform float visibility : hint_range(0.0, 1.0) = 1.0;
uniform float fade_start = 6.0;
uniform float fade_end = 2.0;
varying float camera_distance;
varying vec4 mesh_color;

void vertex() {
    camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
    mesh_color = COLOR;
}
void fragment() {
    ALBEDO = tint.rgb * (vertex_tint ? pow(mesh_color.rgb, vec3(2.2)) : vec3(1.0));
    ROUGHNESS = 0.88;
    BACKLIGHT = ALBEDO * 0.15;
    ALPHA = tint.a * visibility * smoothstep(fade_end, fade_start, camera_distance);
}
