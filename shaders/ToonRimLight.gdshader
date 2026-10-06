shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_toon, specular_disabled;

// Adapted from the shared Ultra pack for the actual textured skeletal mesh.
uniform sampler2D albedo_texture : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(0.64,0.84,0.94,1.0);
uniform float rim_strength = 0.12;
uniform float fill_light = 0.22;

void fragment() {
    vec4 paint = texture(albedo_texture, UV);
    vec2 pixel = 1.4 / vec2(textureSize(albedo_texture, 0));
    float neighbor = min(min(texture(albedo_texture, UV+vec2(pixel.x,0.0)).a,
                             texture(albedo_texture, UV-vec2(pixel.x,0.0)).a),
                         min(texture(albedo_texture, UV+vec2(0.0,pixel.y)).a,
                             texture(albedo_texture, UV-vec2(0.0,pixel.y)).a));
    float silhouette = (1.0-neighbor)*smoothstep(0.18,0.65,paint.a);
    ALBEDO = paint.rgb*tint.rgb;
    ALPHA = paint.a*tint.a;
    ALPHA_SCISSOR_THRESHOLD = 0.10;
    ROUGHNESS = 1.0;
    EMISSION = ALBEDO*fill_light + rim_color.rgb*silhouette*rim_strength*tint.a;
}

void light() {
    float facing = max(0.0,dot(NORMAL,LIGHT));
    float band = mix(0.26,0.72,smoothstep(0.28,0.43,facing));
    DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*band/3.14159265;
}
