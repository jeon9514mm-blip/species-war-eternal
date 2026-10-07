shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform vec4 moss : source_color=vec4(.659,.722,.620,1.0);
uniform vec4 bronze : source_color=vec4(.769,.643,.518,1.0);
uniform float visual_time=0.0;
uniform float glow=.35;
uniform float rotation_speed=.15;
uniform sampler2D artist_circle : source_color,filter_linear_mipmap,repeat_disable;
void fragment(){
    vec2 p=(UV-.5)*2.0;float r=length(p);float a=atan(p.y,p.x)+visual_time*rotation_speed;
    float line=(1.0-smoothstep(.008,.014,abs(r-.90)))+(1.0-smoothstep(.005,.010,abs(r-.70)))*.65;
    float sector=fract((a+3.14159265)*4.0/6.2831853)-.5;
    float stem=(1.0-smoothstep(.018,.035,abs(sector)))*(1.0-smoothstep(.025,.05,abs(r-.8)));
    float rune=(1.0-smoothstep(.04,.06,abs(sector)+abs(r-.8)*1.8))*1.2;
    float inner=exp(-abs(r-.70)*45.0)*.25;
    float particles=0.0;
    for(int i=0;i<8;i++){
        float angle=float(i)*.78539816-visual_time*.15;
        vec2 q=vec2(cos(angle),sin(angle))*.89;
        particles+=exp(-length(p-q)*160.0)*.65;
    }
    float ink=clamp(line+stem+rune+particles+inner,0.0,1.0);
    vec3 color=mix(moss.rgb,bronze.rgb,.5+.5*sin(a*2.0));
    float turn=visual_time*rotation_speed;
    vec2 rotated=mat2(vec2(cos(turn),sin(turn)),vec2(-sin(turn),cos(turn)))*p;
    vec4 art=texture(artist_circle,rotated*.5+.5);
    ALBEDO=mix(color,mix(art.rgb,moss.rgb,.16),art.a);EMISSION=(color*ink+art.rgb*art.a)*glow*3.2;
    ALPHA=max(ink*.72,art.a*.90);
}
