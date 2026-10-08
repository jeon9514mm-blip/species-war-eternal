uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atlas_rect;
uniform vec2 atlas_texel;
uniform vec2 paint_size;
uniform vec2 paint_anchor;
uniform vec4 actor_tint : source_color=vec4(1.0);
uniform float visual_time=0.0;
uniform float facing_sign=1.0;
uniform float hit_flash=0.0;
uniform float wound_strength=0.0;
uniform float movement_heat=0.0;
uniform float outline_px=.8;
uniform float outline_opacity=.6;
uniform float display_height=86.4;
uniform float rim_strength=.25;
uniform float alpha_cutoff=.12;
uniform float secondary_amount=.018;
uniform float secondary_seed=0.0;
uniform float locomotion_weight=0.0;
uniform float action_energy=0.0;
uniform vec2 cape_0;
uniform vec2 cape_1;
uniform vec2 cape_2;
uniform vec2 cape_3;
uniform vec2 cape_4;
uniform bool cape_enabled=false;
varying vec2 local_uv;
void vertex(){
    local_uv=UV;
    vec2 uv=atlas_rect.xy+UV*atlas_rect.zw;
    VERTEX=vec3(UV.x*paint_size.x-paint_anchor.x,paint_anchor.y-UV.y*paint_size.y,VERTEX.z*paint_size.y*.06);
    // All vertices in a draw share this switch. Monster/boss reliefs have no
    // cape, so they can omit the vertex texture fetch and cloth mask entirely.
    if(cape_enabled){
        vec4 ink=textureLod(source_texture,clamp(uv,atlas_rect.xy+atlas_texel*.5,atlas_rect.xy+atlas_rect.zw-atlas_texel*.5),0.0);
        float warm=step(ink.g*1.08,ink.r)*step(ink.b*1.3,ink.g);
        float outer=smoothstep(.20,.36,abs(UV.x-.5));
        float cape=outer*smoothstep(.28,.40,UV.y)*(1.0-smoothstep(.86,.98,UV.y))*(1.0-warm)*ink.a;
        float segment=clamp((UV.y-.3)/.6,0.0,1.0)*4.0;
        vec2 drift=segment<1.0?mix(cape_0,cape_1,segment):(segment<2.0?mix(cape_1,cape_2,segment-1.0):(segment<3.0?mix(cape_2,cape_3,segment-2.0):mix(cape_3,cape_4,segment-3.0)));
        VERTEX.xy+=drift*cape;
    }
    UV=uv;
}
void fragment(){
    vec2 lo=atlas_rect.xy+atlas_texel*.5;vec2 hi=atlas_rect.xy+atlas_rect.zw-atlas_texel*.5;
    vec4 ink=texture(source_texture,clamp(UV,lo,hi));
    float edge=0.0;
    if(outline_px>0.0){
        vec2 d=atlas_texel*outline_px*paint_size.y/max(display_height,1.0);
        edge=max(max(texture(source_texture,clamp(UV+vec2(d.x,0),lo,hi)).a,texture(source_texture,clamp(UV-vec2(d.x,0),lo,hi)).a),max(texture(source_texture,clamp(UV+vec2(0,d.y),lo,hi)).a,texture(source_texture,clamp(UV-vec2(0,d.y),lo,hi)).a));
        edge*=outline_opacity*(1.0-smoothstep(.08,.35,ink.a));
    }
    float warm=smoothstep(.05,.20,ink.r-ink.b)*smoothstep(.4,.7,ink.g);
    float armor=warm*smoothstep(.25,.38,local_uv.y)*(1.0-smoothstep(.8,.96,local_uv.y));
    ALBEDO=mix(mix(ink.rgb*actor_tint.rgb*.82,vec3(1.0,.98,.9),hit_flash),vec3(0.0),edge);
    float scratch=1.0-smoothstep(.005,.014,abs(local_uv.x-.57+(local_uv.y-.6)*.35));
    scratch*=smoothstep(.42,.50,local_uv.y)*(1.0-smoothstep(.73,.83,local_uv.y));
    ALBEDO=mix(ALBEDO,vec3(.27,.055,.065),scratch*wound_strength*.65);
    ROUGHNESS=mix(.82,.58,armor);METALLIC=armor*.32;
    AO=1.0-(1.0-smoothstep(.05,.28,dot(ink.rgb,vec3(.299,.587,.114))))*.30;
    EMISSION=ALBEDO*.08;
    RIM=rim_strength;RIM_TINT=.35;
#ifdef TRUE_SSS
    SSS_STRENGTH=.25;
#else
    // Mobile supports native PBR and rim; warm transmission is approximated.
    EMISSION+=ALBEDO*warm*.25*.15;
#endif
    ALPHA=max(ink.a,edge)*actor_tint.a;ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;
}
