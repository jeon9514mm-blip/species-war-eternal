shader_type canvas_item;
uniform float bloom=.45;
uniform float bloom_strength=.9;
uniform float vignette=.70;
uniform float light_shafts=.15;
void fragment(){
    vec4 base=texture(TEXTURE,UV);vec2 px=TEXTURE_PIXEL_SIZE*2.0;vec3 glow=vec3(0.0);
    for(int i=0;i<4;i++){
        vec2 offset=vec2(i<2?-1.0:1.0,i%2==0?-1.0:1.0)*px;
        vec3 sample_color=texture(TEXTURE,UV+offset).rgb;glow+=max(sample_color-vec3(.72),vec3(0.0));
    }
    vec2 p=(UV-.5)*2.0;float shade=1.0-vignette*smoothstep(.55,1.35,length(p))*.38;
    // Three analytic diagonal shafts add depth in the Mobile renderer without
    // volumetric fog, ray marching or another full-screen texture pass.
    float shaft_x=UV.x+UV.y*.45;
    float rays=exp(-pow((shaft_x-.32)*10.0,2.0))*.45;
    rays+=exp(-pow((shaft_x-.78)*14.0,2.0))*.30;
    rays+=exp(-pow((shaft_x-1.12)*18.0,2.0))*.22;
    rays*=pow(1.0-UV.y,1.5)*light_shafts;
    COLOR=vec4((base.rgb+glow*bloom*.25*bloom_strength+vec3(.76,.85,.66)*rays)*shade,base.a);
}
