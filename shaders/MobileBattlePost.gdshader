shader_type canvas_item;
uniform float bloom=.35;
uniform float vignette=.65;
void fragment(){
    vec4 base=texture(TEXTURE,UV);vec2 px=TEXTURE_PIXEL_SIZE*2.0;vec3 glow=vec3(0.0);
    for(int i=0;i<4;i++){
        vec2 offset=vec2(i<2?-1.0:1.0,i%2==0?-1.0:1.0)*px;
        vec3 sample_color=texture(TEXTURE,UV+offset).rgb;glow+=max(sample_color-vec3(.72),vec3(0.0));
    }
    vec2 p=(UV-.5)*2.0;float shade=1.0-vignette*smoothstep(.55,1.35,length(p))*.38;
    COLOR=vec4((base.rgb+glow*bloom*.25)*shade,base.a);
}
