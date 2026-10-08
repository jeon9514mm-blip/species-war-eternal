shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
varying float print_opacity;
void vertex() { print_opacity=INSTANCE_CUSTOM.r; }
void fragment() {
    vec2 p=UV-.5;
    float sole=1.0-smoothstep(.80,1.0,length(p/vec2(.28,.44)));
    float heel=1.0-smoothstep(.8,1.0,length((p-vec2(0,.17))/vec2(.22,.16)));
    float tread=(.72+.28*smoothstep(.25,.65,abs(sin(p.y*48.0))));
    ALBEDO=vec3(.105,.125,.108);
    ALPHA=max(sole,heel)*tread*print_opacity;
}
