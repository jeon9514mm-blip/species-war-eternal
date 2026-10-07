shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atlas_rect;
uniform vec2 atlas_texel;
uniform float shell_layer = 0.5;
uniform float fur_length = 5.0;
uniform float visual_time = 0.0;
uniform bool hair_only = false;
vec4 sample_paint(vec2 uv) {
    vec2 lo=atlas_rect.xy+atlas_texel*.5,hi=atlas_rect.xy+atlas_rect.zw-atlas_texel*.5;
    vec4 value=texture(source_texture,clamp(uv,lo,hi));
    value.a*=step(lo.x,uv.x)*step(lo.y,uv.y)*step(uv.x,hi.x)*step(uv.y,hi.y);return value;
}
void fragment() {
    vec2 local=(UV-atlas_rect.xy)/atlas_rect.zw;
    vec2 wind=vec2(sin(visual_time*.8+local.y*5.0)*.08,-.25);
    vec2 tap=atlas_texel*fur_length*shell_layer;
    vec4 center=sample_paint(UV);
    vec4 strand=sample_paint(UV+tap*(vec2(1,0)+wind));
    vec4 other=sample_paint(UV+tap*(vec2(-1,0)+wind));
    if(other.a>strand.a)strand=other;
    other=sample_paint(UV+tap*(vec2(0,1)+wind));if(other.a>strand.a)strand=other;
    other=sample_paint(UV+tap*(vec2(0,-1)+wind));if(other.a>strand.a)strand=other;
    float edge=max(0.0,step(.45,strand.a)-smoothstep(.08,.4,center.a));
    float noise=fract(sin(dot(floor(UV/atlas_texel),vec2(12.9898,78.233))+shell_layer*19.0)*43758.5453);
    float mask=hair_only?(1.0-smoothstep(.23,.32,local.y))*(1.0-smoothstep(.12,.22,strand.r-strand.b)):1.0;
    ALBEDO=strand.rgb*(.90+.10*shell_layer);
    ALPHA=edge*mask*step(.40+shell_layer*.28,noise)*(.26-shell_layer*.15);
}
