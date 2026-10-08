shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Fixed four-map PBR budget; 4/8-step height traversal never grows with actors.
uniform sampler2D stone_art : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_micro_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_surface : filter_linear_mipmap, repeat_enable;
uniform vec2 tile_scale = vec2(11.111111,8.75);
uniform float roughness = .58;
uniform float metallic = .32;
uniform float normal_strength = .28;
uniform float micro_strength = .22;
uniform float micro_world_scale = 1.7;
uniform float height_scale = .08;
uniform int parallax_steps = 4;
uniform float ao_strength = .7;
uniform float edge_wear = .8;
uniform float moss_glow = .25;
uniform vec4 moss_color : source_color = vec4(.659,.722,.620,1.0);
// These are the real raid movement bounds in the common 45 degree ground plane.
uniform vec2 arena_min = vec2(-7.461538,4.3975);
uniform vec2 arena_max = vec2(39.461538,15.6025);
uniform vec4 court_tint : source_color = vec4(.67,.70,.65,1.0);
uniform vec4 outer_tint : source_color = vec4(.18,.23,.26,1.0);
uniform vec4 inlay_color : source_color = vec4(.70,.60,.44,1.0);
uniform vec4 sigil_color : source_color = vec4(.52,.78,.79,1.0);
varying vec3 stone_world_position;
varying vec3 stone_world_normal;
void vertex() {
    stone_world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    stone_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 triplanar_micro(vec3 point, vec3 normal) {
    vec3 weights = pow(abs(normal),vec3(6.0));
    weights /= max(.0001,weights.x+weights.y+weights.z);
    vec3 ny = texture(stone_micro_normal,point.xz).rgb*2.0-1.0;
    // The game's complete floor is horizontal: avoid two unused texture reads.
    if (weights.y > .995) { return normalize(vec3(ny.x,ny.z,ny.y)); }
    vec3 nx = texture(stone_micro_normal,point.zy).rgb*2.0-1.0;
    vec3 nz = texture(stone_micro_normal,point.xy).rgb*2.0-1.0;
    return normalize(vec3(nx.z*sign(normal.x),nx.y,nx.x)*weights.x
        + vec3(ny.x,ny.z*sign(normal.y),ny.y)*weights.y
        + vec3(nz.x,nz.y,nz.z*sign(normal.z))*weights.z);
}
void fragment() {
    vec2 tile_uv = UV * tile_scale;
    vec2 view_tangent = vec2(dot(VIEW,TANGENT),dot(VIEW,BINORMAL));
    view_tangent /= max(.35,abs(dot(VIEW,NORMAL)));
    int steps = clamp(parallax_steps,0,8);
    if (steps > 0) {
        vec2 ray = view_tangent*height_scale/float(steps);
        vec2 traversed = tile_uv;
        float layer = 0.0;
        float sample_height = 1.0-texture(stone_surface,traversed).r;
        vec2 previous = traversed;
        for (int i=0;i<8;i++) {
            if (i>=steps || layer>=sample_height) { break; }
            previous=traversed;
            traversed-=ray;layer+=1.0/float(steps);
            sample_height=1.0-texture(stone_surface,traversed).r;
        }
        // Linear crossing refinement removes the visible layer staircase.
        float after_depth = sample_height-layer;
        float before_depth = 1.0-texture(stone_surface,previous).r-layer+1.0/float(steps);
        float crossing=clamp(after_depth/(after_depth-before_depth-.00001),0.0,1.0);
        tile_uv=mix(traversed,previous,crossing);
    }
    vec4 stone = texture(stone_art,tile_uv);
    vec4 surface=texture(stone_surface,tile_uv);
    vec3 macro=texture(stone_normal,tile_uv).rgb*2.0-1.0;
    vec3 micro=triplanar_micro(stone_world_position*micro_world_scale,normalize(stone_world_normal));
    vec3 world_tangent=normalize((INV_VIEW_MATRIX*vec4(TANGENT,0.0)).xyz);
    vec3 world_binormal=normalize((INV_VIEW_MATRIX*vec4(BINORMAL,0.0)).xyz);
    vec3 detail=vec3(dot(micro,world_tangent),dot(micro,world_binormal),dot(micro,normalize(stone_world_normal)));
    NORMAL_MAP=normalize(vec3(macro.xy+detail.xy*micro_strength,macro.z))*.5+.5;
    NORMAL_MAP_DEPTH = normal_strength;
    float wet=surface.a;
    ALBEDO=stone.rgb*(1.0-surface.g*.12)*(1.0-wet*.15);
    ALBEDO+=vec3(.014,.015,.014)*surface.b*edge_wear;
    ROUGHNESS=mix(roughness,.14,wet);
    METALLIC=mix(metallic,.40,wet);
    SPECULAR=mix(.42,.85,wet);
    AO=stone.a;
    AO_LIGHT_AFFECT=ao_strength;
    // Moss mask comes from authored green pigment, still confined to cracks.
    float green = stone.g - (stone.r+stone.b)*.5;
    float moss = smoothstep(.025,.055,green);
    EMISSION = moss_color.rgb * moss * moss_glow;
    // A quiet court and darker perimeter distinguish the floor from scenery.
    // Constant pigment, no extra textures, animated uniforms, or light passes.
    vec2 center=(arena_min+arena_max)*.5;
    vec2 half_size=(arena_max-arena_min)*.5;
    vec2 edge=abs(stone_world_position.xz-center)-half_size;
    float signed_edge=max(edge.x,edge.y);
    float court=1.0-smoothstep(-.05,.05,signed_edge);
    // Long staggered slabs make the encounter floor legible even in a small
    // window. The resident paint remains the micro detail inside each slab.
    vec2 grid=(stone_world_position.xz-arena_min)/vec2(3.60,1.60);
    grid.x+=mod(floor(grid.y),2.0)*.5;
    vec2 cell=fract(grid);
    vec2 seam=min(cell,1.0-cell);
    float grout=1.0-smoothstep(.009,.022,min(seam.x,seam.y));
    float worn=smoothstep(.022,.040,min(seam.x,seam.y))
        -smoothstep(.040,.065,min(seam.x,seam.y));
    float variation=fract(sin(dot(floor(grid),vec2(12.9898,78.233)))*43758.5453);
    vec3 carved=mix(vec3(.43,.45,.42),stone.rgb,.42)*court_tint.rgb;
    carved*=.88+variation*.16;
    carved=carved*(1.0-grout*.52)+worn*vec3(.04,.038,.031);
    vec3 perimeter=ALBEDO*outer_tint.rgb*.80;
    ALBEDO=mix(perimeter,carved,court);
    AO*=1.0-grout*court*.24;
    float inlay=1.0-smoothstep(.025,.070,abs(signed_edge-.72));
    float inner=1.0-smoothstep(.020,.055,abs(signed_edge+.16));
    ALBEDO=mix(ALBEDO,inlay_color.rgb,inlay*.82+inner*.50);
    ROUGHNESS=mix(ROUGHNESS,.48,inlay);
    METALLIC=mix(METALLIC,.42,inlay);
    vec2 local=(stone_world_position.xz-center)/vec2(6.5,4.0);
    float ring=1.0-smoothstep(.008,.020,abs(length(local)-1.0));
    float cuts=smoothstep(.40,.54,abs(cos(atan(local.y,local.x)*6.0)));
    float seal=ring*cuts*court;
    ALBEDO=mix(ALBEDO,inlay_color.rgb,seal*.22);
    EMISSION=EMISSION*court*.45+sigil_color.rgb*(inlay*.05+seal*.035);
}
