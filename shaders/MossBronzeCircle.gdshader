shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform vec4 moss : source_color=vec4(.659,.722,.620,1.0);
uniform vec4 bronze : source_color=vec4(.910,.788,.604,1.0);
uniform float visual_time=0.0;
uniform float glow=.5;
uniform float inner_glow=.35;
uniform float pulse_period=.8;
uniform float rotation_speed=.12;
uniform float rune_brightness=.7;
uniform int rune_count=8;
uniform sampler2D artist_circle : source_color,filter_linear_mipmap,repeat_disable;
void fragment(){
    vec2 p=(UV-.5)*2.0;float r=length(p);float a=atan(p.y,p.x)+visual_time*rotation_speed;
    float line=(1.0-smoothstep(.008,.014,abs(r-.90)))+(1.0-smoothstep(.005,.010,abs(r-.70)))*.65;
    float sector=fract((a+3.14159265)*float(rune_count)/6.2831853)-.5;
    float stem=(1.0-smoothstep(.018,.035,abs(sector)))*(1.0-smoothstep(.025,.05,abs(r-.8)));
    float rune=(1.0-smoothstep(.04,.06,abs(sector)+abs(r-.8)*1.8))*1.2;
    float inner=exp(-abs(r-.70)*45.0)*inner_glow;
    // Nearest angular sectors evaluate all eight motes/twelve leaves in
    // constant cost per fragment, rather than 28 loop iterations per pixel.
    float base_angle=atan(p.y,p.x);
    float mote_angle=fract((a+3.14159265)*8.0/6.2831853)-.5;
    float particles=exp(-length(vec2(mote_angle*.78539816*r,r-.89))*160.0)*.65;
    float leaf_sector=floor((base_angle-visual_time*.10+3.14159265)*12.0/6.2831853+.5);
    float seed=leaf_sector*6.2831853/12.0-3.14159265;
    float falling=fract(visual_time*.13+leaf_sector/12.0);
    float leaf_angle=seed+visual_time*.10;
    vec2 center=vec2(cos(leaf_angle),sin(leaf_angle))*(.74+falling*.22);
    vec2 leaf=p-center;
    leaf=mat2(vec2(cos(seed),sin(seed)),vec2(-sin(seed),cos(seed)))*leaf;
    float leaves=(1.0-smoothstep(.65,1.0,length(leaf/vec2(.015,.030))))*sin(falling*3.14159265)*.5;
    float radial=abs(sin(base_angle*4.0))*r*.25;
    float fork=.008*sin(r*65.0+floor((base_angle+3.14159265)*8.0/6.2831853));
    float cracks=(1.0-smoothstep(.002,.006,abs(radial+fork)))*smoothstep(.87,.92,r)*(1.0-smoothstep(.97,1.0,r));
    float ink=clamp(line+(stem+rune)*rune_brightness+particles+inner+leaves,0.0,1.0);
    vec3 color=mix(moss.rgb,bronze.rgb,.5+.5*sin(a*2.0));
    float turn=visual_time*rotation_speed;
    vec2 rotated=mat2(vec2(cos(turn),sin(turn)),vec2(-sin(turn),cos(turn)))*p;
    vec4 art=texture(artist_circle,rotated*.5+.5);
    float rune_band=smoothstep(.735,.76,r)*(1.0-smoothstep(.85,.875,r));
    art.a*=1.0-rune_band*.65;
    float pulse=.88+.12*sin(visual_time*6.2831853/max(.1,pulse_period));
    ALBEDO=mix(color,mix(art.rgb,moss.rgb,.16),art.a);
    ALBEDO=mix(ALBEDO,vec3(.055,.065,.055),clamp(cracks,0.0,1.0)*.8);
    EMISSION=(color*ink+art.rgb*art.a)*glow*2.0*pulse;
    EMISSION*=1.0-clamp(cracks,0.0,1.0)*.85;
    ALPHA=max(max(ink*.72,art.a*.90),cracks*.65);
}
