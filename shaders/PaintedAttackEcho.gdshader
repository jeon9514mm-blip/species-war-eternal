shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D source_texture : source_color, filter_linear, repeat_disable;
uniform vec4 atlas_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec2 atlas_texel = vec2(.001);
uniform vec4 echo_tint : source_color = vec4(.78,.83,.70,1.0);
uniform float opacity = 0.0;
void fragment() {
    vec2 lo=atlas_rect.xy+atlas_texel*.5;
    vec2 hi=atlas_rect.xy+atlas_rect.zw-atlas_texel*.5;
    vec4 paint=texture(source_texture,clamp(UV,lo,hi));
    if (paint.a<.05 || UV.x<lo.x || UV.y<lo.y || UV.x>hi.x || UV.y>hi.y) discard;
    ALBEDO=mix(paint.rgb,echo_tint.rgb,.38);
    ALPHA=paint.a*opacity;
}
