shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Offline baked footprint with five texture taps. Native directional shadows
// use Godot 4 Vogel-disk PCF; this is the low-cost contact component.
uniform sampler2D baked_mask : filter_linear,repeat_disable;
void fragment() {
    vec2 tap=vec2(1.0/128.0);
    float falloff=(texture(baked_mask,UV).r*2.0+texture(baked_mask,UV+vec2(tap.x,0)).r+texture(baked_mask,UV-vec2(tap.x,0)).r+texture(baked_mask,UV+vec2(0,tap.y)).r+texture(baked_mask,UV-vec2(0,tap.y)).r)/6.0;
    ALBEDO = vec3(0.055, 0.075, 0.06);
    ALPHA = falloff * 0.50;
}
