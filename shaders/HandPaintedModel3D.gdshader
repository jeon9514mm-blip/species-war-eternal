shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D original_paint : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 actor_tint : source_color = vec4(1.0);
uniform vec4 paint_rect;
uniform float hit_flash = 0.0;
void fragment() {
    vec4 painted=texture(original_paint,UV);
    float inside=step(paint_rect.x,UV.x)*step(paint_rect.y,UV.y)*step(UV.x,paint_rect.z)*step(UV.y,paint_rect.w);
    float weight=COLOR.a*painted.a*inside;
    vec3 color=mix(base_color.rgb,painted.rgb,weight*.96)*actor_tint.rgb;
    ALBEDO=mix(color,vec3(1.0),hit_flash);
    ROUGHNESS=.95;
    SPECULAR=0.0;
    EMISSION=color*.13;
}
