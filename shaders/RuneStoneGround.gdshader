shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_never;
uniform sampler2D stone_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool rune_only = false;
uniform float detail_strength = 0.14;
uniform vec4 stone_tint : source_color = vec4(1.0);
uniform vec4 rune_color : source_color = vec4(0.18, 0.75, 1.0, 1.0);
uniform float tiling = 5.5;
uniform float macro_variation = 0.015;
uniform float crack_depth = 0.65;
uniform float moss_amount = 0.18;
uniform float puddle_coverage = 0.25;
uniform float wetness = 0.28;
uniform float rune_power = 1.25;
uniform float edge_wear = 0.48;
uniform float visual_time = 0.0;
uniform vec4 moss_rune : source_color = vec4(.658,.721,.619,1.0);
uniform vec4 bronze_rune : source_color = vec4(.768,.643,.517,1.0);
uniform float rune_rotation_speed = .15;
// Meta v33 detail adapted to the real stone painting. Screen derivatives stop
// microscopic grain from aliasing; no fabricated 32K maps or virtual geometry.
uniform float micro_detail = 0.014;
uniform vec2 rune_center = vec2(16.0, 10.0);
uniform float rune_radius = 3.8;
uniform float rune_sectors = 8.0;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float band(float r, float at, float width) { return 1.0-smoothstep(width,width+0.004,abs(r-at)); }
void vertex() {
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    // Subtle visual relief, safely below the actor feet. No gameplay collisions.
    if (!rune_only) VERTEX.y += (noise(p.xz*0.12)-0.5)*0.055+(noise(p.xz*0.35)-0.5)*0.020;
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    vec2 world=world_position.xz;
    // Ground is near-horizontal: the dominant XZ triplanar projection has no seam.
    vec2 uv=world*tiling*0.013 + vec2(noise(world*0.065),noise(world*0.065+19.0))*0.035;
    float variation=noise(world*0.045)*6.0;
    float stone_variant=floor(variation);
    vec2 offset_a=vec2(hash(vec2(stone_variant,3.0)),hash(vec2(stone_variant,11.0)));
    vec2 offset_b=vec2(hash(vec2(stone_variant+1.0,3.0)),hash(vec2(stone_variant+1.0,11.0)));
    vec3 paint=mix(texture(stone_art,uv+offset_a).rgb,texture(stone_art,uv+offset_b).rgb,smoothstep(0.2,0.8,fract(variation)));
    float painted_luma=dot(paint,vec3(0.2126,0.7152,0.0722));
    paint=mix(vec3(painted_luma),paint,0.95)*1.10;
    float value=dot(paint,vec3(0.2126,0.7152,0.0722));
    float crack=1.0-smoothstep(0.07,0.22,value);
    float macro=noise(world*macro_variation);
    // Lower floor values separate the bright original paintings from the stone.
    vec3 stone=paint*stone_tint.rgb*mix(0.26,0.40,macro);
    stone*=mix(1.0,0.45,crack*crack_depth);
    float low=1.0-smoothstep(-0.02,0.015,world_position.y);
    float moss=crack*low*(0.4+noise(world*0.6)*0.6)*moss_amount;
    stone=mix(stone,vec3(0.12,0.23,0.14),moss*0.65);
    float distance_to_center=length(world-rune_center);
    float center_wet=1.0-smoothstep(5.5,9.5,distance_to_center);
    float patches=smoothstep(1.0-puddle_coverage,1.0-puddle_coverage+0.18,noise(world*0.28+27.0));
    float puddle=center_wet*patches*mix(0.30,1.0,max(crack,low))*wetness;
    stone=mix(stone,stone*0.69,puddle);
    float droplet=step(0.92,sin(world.x*18.3)*sin(world.y*17.7));
    stone+=vec3(droplet*(1.0-crack)*puddle*0.045);
    // Derivative bump from the artist's cracks, with restrained edge highlights.
    float dx=dFdx(value),dy=dFdy(value);
    NORMAL=normalize(NORMAL-vec3(dx,0.0,dy)*2.5);
    stone+=vec3(clamp(length(vec2(dx,dy))*4.0,0.0,0.08)*edge_wear);
    float detail_lod=1.0-smoothstep(.20,.65,length(fwidth(world))*14.0);
    float grain=(noise(world*14.0)-.5)*micro_detail*detail_lod;
    stone+=vec3(grain)*(1.0-puddle*.5);
    float detail=texture(stone_detail,world*.8).r-.5;
    stone*=1.0+detail*detail_strength*detail_lod;
    float radius=distance_to_center/rune_radius;
    float rings=band(radius,0.90,0.009)+band(radius,0.70,0.007);
    float angle=atan(world.y-rune_center.y,world.x-rune_center.x)+visual_time*rune_rotation_speed;
    float sector=(angle+3.14159265)*rune_sectors/6.2831853;
    float column=fract(sector)-0.5;
    float variant=hash(vec2(floor(sector),8.0));
    float stem=(1.0-smoothstep(0.030,0.055,abs(column)))*band(radius,0.80,0.036);
    float arm=(1.0-smoothstep(0.18,0.23,abs(column)))*band(radius,0.79+step(0.5,variant)*0.022,0.003);
    float diagonal=(1.0-smoothstep(0.028,0.06,abs(column-(radius-0.8)*3.4)))*band(radius,0.8,0.022);
    float glyph=clamp(stem+arm+diagonal*step(0.25,variant),0.0,1.0);
    float halo=(1.0-smoothstep(0.008,0.055,abs(radius-0.9)))+(1.0-smoothstep(0.006,0.04,abs(radius-0.7)));
    float pulse=sin(visual_time*1.65+world.x*0.07)*0.22+0.78;
    float flicker=0.97+0.03*sin(visual_time*7.3+sector);
    vec3 ring_color=mix(moss_rune.rgb,bronze_rune.rgb,.5+.5*sin(angle*rune_sectors));
    ring_color=mix(ring_color,rune_color.rgb,.12);
    // Colored inlay carries the design; restrained emission avoids white bloom.
    ALBEDO=mix(stone,ring_color*.60,clamp(rings+glyph,0.0,1.0))+ring_color*halo*.015;
    ROUGHNESS=mix(mix(.58,.82,crack),.28,clamp(puddle/.40,0.0,1.0));
    METALLIC=clamp(puddle*.12+rings*.32,0.0,.40);
    AO=clamp(1.0-crack*crack_depth*.25,0.65,1.0);
    float flow=fract(sector/rune_sectors*1.6+visual_time*.08);
    float sweep=smoothstep(0.0,0.07,flow)*(1.0-smoothstep(0.93,1.0,flow));
    float spark_angle=fract(sector+visual_time*.11)-.5;
    float spark=(1.0-smoothstep(.012,.045,abs(spark_angle)))*band(radius,.90+.028*sin(sector+visual_time),.009);
    EMISSION=ring_color*(rings*.22+glyph*.30+halo*.018+spark*.35)*rune_power*pulse*flicker;
    EMISSION+=bronze_rune.rgb*rings*sweep*.12;
    ALPHA=rune_only ? clamp(rings+glyph+halo*.12,0.0,1.0)*.55 : 1.0;
}
