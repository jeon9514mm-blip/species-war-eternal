shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform float art_time = 0.0;
uniform float horizon_z = -30.0;
varying vec3 world_position;
varying float blade_height;

void vertex() {
    blade_height = max(VERTEX.y + .012, 0.0);
    vec2 anchor = VERTEX.xz;
    // The root remains on the floor. Only the upper blade catches the breeze.
    float breeze = sin(art_time * 1.35 + anchor.x * .35 + anchor.y * .24);
    VERTEX.x += breeze * blade_height * .12;
    VERTEX.z += sin(art_time * .9 + anchor.y * .4) * blade_height * .05;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    if (world_position.z < horizon_z) { discard; }
    vec3 tip = vec3(.04, .055, .015) * smoothstep(.08, .44, blade_height);
    ALBEDO = COLOR.rgb + tip;
    ALPHA = smoothstep(horizon_z, horizon_z + 2.8, world_position.z);
}
