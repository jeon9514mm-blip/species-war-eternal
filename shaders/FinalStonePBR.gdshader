shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Coverage, crack darkness and edge wear are authored into the same 1024 maps.
// Two texture reads preserve the existing 2.8 MB compressed floor budget.
uniform sampler2D stone_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tile_scale = vec2(11.111111,8.75);
uniform float roughness = .58;
uniform float metallic = .32;
uniform float normal_strength = .28;
uniform float moss_glow = .15;
uniform vec4 moss_color : source_color = vec4(.659,.722,.620,1.0);
void fragment() {
    vec2 tile_uv = UV * tile_scale;
    vec4 stone = texture(stone_art,tile_uv);
    ALBEDO = stone.rgb;
    NORMAL_MAP = texture(stone_normal,tile_uv).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    AO = stone.a;
    AO_LIGHT_AFFECT = .5;
    // The authoring pass confines this green pigment to cracks. Its measured
    // green contrast lights moss without a third full-size mask texture.
    float green = stone.g - (stone.r+stone.b)*.5;
    float moss = smoothstep(.025,.055,green);
    EMISSION = moss_color.rgb * moss * moss_glow;
}
