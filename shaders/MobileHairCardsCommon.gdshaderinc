uniform sampler2D source_texture : source_color,filter_linear_mipmap,repeat_disable;
uniform vec4 atlas_rect;
uniform vec2 atlas_texel;
uniform vec2 paint_size;
uniform vec2 paint_anchor;
uniform vec4 hair_rect;
uniform vec4 actor_tint : source_color=vec4(1.0);
uniform float visual_time;
uniform float wind_strength=.15;
uniform float clump=.30;
uniform float frizz=.10;
uniform float rim_strength=.25;
varying vec2 card_uv;
void vertex(){
    card_uv=UV;
    vec2 local=hair_rect.xy+UV*hair_rect.zw;
    VERTEX=vec3(local.x*paint_size.x-paint_anchor.x,paint_anchor.y-local.y*paint_size.y,.15);
    float cluster=floor(UV.x*12.0)/12.0;
    float phase=mix(UV.x,cluster,clump)*11.0;
    float sway=sin(visual_time*2.3+phase+UV.y*4.0)*wind_strength*2.5;
    float loose=sin(visual_time*4.2+UV.x*91.0+UV.y*37.0)*frizz*.45;
    VERTEX.x+=(sway+loose)*smoothstep(.12,.80,UV.y);
    NORMAL=vec3(0.0,0.0,1.0);TANGENT=vec3(0.0,1.0,0.0);BINORMAL=vec3(1.0,0.0,0.0);
    UV=atlas_rect.xy+local*atlas_rect.zw;
}
void fragment(){
    vec2 lo=atlas_rect.xy+atlas_texel*.5;vec2 hi=atlas_rect.xy+atlas_rect.zw-atlas_texel*.5;
    vec4 ink=texture(source_texture,clamp(UV,lo,hi));
    // Original sheet pixels stay untouched; clip the lower central face out of hair.
    float side=smoothstep(.17,.37,abs(card_uv.x-.5));
    float mask=max(1.0-smoothstep(.38,.72,card_uv.y),side);
    ALBEDO=ink.rgb*actor_tint.rgb*.94;ROUGHNESS=.74;METALLIC=0.0;
    ANISOTROPY=.72;ANISOTROPY_FLOW=vec2(0.0,1.0);
    RIM=rim_strength;RIM_TINT=.65;
    EMISSION=ALBEDO*.10;
#ifdef TRUE_SSS
    SSS_STRENGTH=.25;
#else
    EMISSION+=ALBEDO*.25*.08;
#endif
    ALPHA=ink.a*actor_tint.a*mask;ALPHA_SCISSOR_THRESHOLD=.20;
}
