shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
// Complete painted poses remain intact. Lighting never moves separate limbs.
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 atlas_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec2 atlas_texel = vec2(0.001);
uniform vec4 actor_tint : source_color = vec4(1.0);
uniform float outline_px = 0.35;
uniform float rim_strength = 0.06;
uniform float alpha_cutoff = 0.12;
uniform float facing_sign = 1.0;
uniform float movement_heat = 0.0;
uniform float visual_time = 0.0;
uniform float hit_flash = 0.0;
uniform vec2 paint_size = vec2(1.0);
uniform float secondary_amount = 0.0;
uniform float secondary_seed = 0.0;
uniform float locomotion_weight = 0.0;
uniform float action_energy = 0.0;
void vertex() {
    // A single dense painting surface. Faces, hands and planted feet remain
    // fixed; only colored outer cloth and hair tips receive a small local sway.
    // visual_time is the paused battle clock, never the engine's global TIME.
    vec2 local=(UV-atlas_rect.xy)/atlas_rect.zw;
    vec2 bounded=clamp(UV,atlas_rect.xy+atlas_texel*.5,atlas_rect.xy+atlas_rect.zw-atlas_texel*.5);
    vec4 ink=textureLod(source_texture,bounded,0.0);
    float hi=max(ink.r,max(ink.g,ink.b));
    float lo=min(ink.r,min(ink.g,ink.b));
    float color=smoothstep(.08,.24,hi-lo)*(1.0-smoothstep(.85,.98,hi));
    float warm=step(ink.g*1.08,ink.r)*step(ink.b*1.3,ink.g);
    float outer=smoothstep(.19,.34,abs(local.x-.5));
    float cape=outer*smoothstep(.22,.40,local.y)*(1.0-smoothstep(.86,.98,local.y))*color*(1.0-warm);
    float hair=smoothstep(.07,.13,abs(local.x-.5))*(1.0-smoothstep(.21,.28,abs(local.x-.5)));
    hair*=smoothstep(.025,.10,local.y)*(1.0-smoothstep(.21,.29,local.y))*.24;
    float swing=sin(visual_time*2.6+local.y*6.0+secondary_seed);
    float momentum=.55+locomotion_weight*.45+action_energy*.25;
    VERTEX.x+=swing*paint_size.x*secondary_amount*(cape+hair)*momentum*ink.a;
    VERTEX.y+=cos(visual_time*2.6+local.x*5.0+secondary_seed)*paint_size.y*secondary_amount*.12*cape*ink.a;
}
vec4 sample_paint(vec2 uv) {
    vec2 lo=atlas_rect.xy+atlas_texel*.5;
    vec2 hi=atlas_rect.xy+atlas_rect.zw-atlas_texel*.5;
    float inside=step(lo.x,uv.x)*step(lo.y,uv.y)*step(uv.x,hi.x)*step(uv.y,hi.y);
    vec4 value=texture(source_texture,clamp(uv,lo,hi));value.a*=inside;return value;
}
void fragment() {
    vec4 base=sample_paint(UV);
    vec2 tap=clamp(fwidth(UV)*outline_px,atlas_texel*.35,atlas_texel*2.0);
    float edge=max(max(sample_paint(UV+vec2(tap.x,0)).a,sample_paint(UV-vec2(tap.x,0)).a),max(sample_paint(UV+vec2(0,tap.y)).a,sample_paint(UV-vec2(0,tap.y)).a));
    float contour=max(0.0,edge-base.a)*.6;
    float rim=max(0.0,base.a-sample_paint(UV+tap*vec2(-facing_sign,-1)).a)*rim_strength;
    vec2 local=(UV-atlas_rect.xy)/atlas_rect.zw;
    // Restrained exertion tint on warm, light face pixels only. Paint is unchanged.
    float warm=smoothstep(.04,.14,base.r-base.b)*smoothstep(.30,.55,base.g)*(1.0-smoothstep(.15,.30,abs(base.r-base.g)));
    float face=(1.0-smoothstep(.24,.38,local.y))*warm;
    float pulse=.85+.15*sin(visual_time*7.85);
    vec3 color=base.rgb+vec3(1.0,.94,.76)*rim;
    color=mix(color,color*vec3(1.02,.97,.97),face*movement_heat*pulse);
    float opacity=base.a+contour*(1.0-base.a);
    ALBEDO=mix(vec3(.08,.12,.15),min(color,vec3(1)),base.a/max(opacity,.0001))*actor_tint.rgb;
    ALBEDO=mix(ALBEDO,vec3(1.0,.98,.90),hit_flash);
    ALPHA=opacity*actor_tint.a;ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;
}
