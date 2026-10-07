shader_type spatial;
render_mode unshaded,cull_disabled,depth_prepass_alpha;
uniform sampler2D source_texture : source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 atlas_rect;
uniform vec2 atlas_texel;
uniform vec2 paint_size;
uniform vec2 paint_anchor;
uniform vec4 hair_rect;
uniform vec4 actor_tint : source_color=vec4(1.0);
uniform float visual_time;
void vertex(){
    vec2 local=hair_rect.xy+UV*hair_rect.zw;
    VERTEX=vec3(local.x*paint_size.x-paint_anchor.x,paint_anchor.y-local.y*paint_size.y,.15);
    VERTEX.x+=sin(visual_time*2.3+UV.y*4.0)*.35*smoothstep(.2,.8,UV.y);
    UV=atlas_rect.xy+local*atlas_rect.zw;
}
void fragment(){
    vec2 lo=atlas_rect.xy+atlas_texel*.5;vec2 hi=atlas_rect.xy+atlas_rect.zw-atlas_texel*.5;
    vec4 ink=texture(source_texture,clamp(UV,lo,hi));ALBEDO=ink.rgb*actor_tint.rgb;
    ALPHA=ink.a*actor_tint.a;ALPHA_SCISSOR_THRESHOLD=.20;
}
