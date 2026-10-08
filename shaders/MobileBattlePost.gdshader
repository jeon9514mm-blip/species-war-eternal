shader_type canvas_item;
uniform float bloom=.60;
uniform float bloom_strength=.9;
uniform float vignette=.75;
uniform float light_shafts=.25;
uniform float chromatic=0.0;
uniform float film_grain=0.0;
uniform float lens_distortion=0.0;
uniform float visual_time=0.0;
uniform float impact_blur=0.0;
void fragment(){
    vec2 centered=UV-.5;
    vec2 uv=clamp(UV+centered*dot(centered,centered)*lens_distortion,vec2(.001),vec2(.999));
    vec4 base=texture(TEXTURE,uv);vec2 px=TEXTURE_PIXEL_SIZE*2.0;vec3 glow=vec3(0.0);
    if(impact_blur>.00001){
        vec2 direction=centered*impact_blur;
        base.rgb=mix(base.rgb,(texture(TEXTURE,uv-direction).rgb+texture(TEXTURE,uv-direction*.5).rgb)*.5,.22);
    }
    if(chromatic>.00001){
        vec2 shift=centered*chromatic*.012;
        base.r=texture(TEXTURE,uv+shift).r;base.b=texture(TEXTURE,uv-shift).b;
    }
    for(int i=0;i<4;i++){
        vec2 offset=vec2(i<2?-1.0:1.0,i%2==0?-1.0:1.0)*px;
        vec3 sample_color=texture(TEXTURE,uv+offset).rgb;glow+=max(sample_color-vec3(.72),vec3(0.0));
    }
    vec2 p=(UV-.5)*2.0;float shade=1.0-vignette*smoothstep(.55,1.35,length(p))*.38;
    // Three analytic diagonal shafts add depth in the Mobile renderer without
    // volumetric fog, ray marching or another full-screen texture pass.
    float shaft_x=UV.x+UV.y*.45;
    float rays=exp(-pow((shaft_x-.32)*10.0,2.0))*.45;
    rays+=exp(-pow((shaft_x-.78)*14.0,2.0))*.30;
    rays+=exp(-pow((shaft_x-1.12)*18.0,2.0))*.22;
    rays*=pow(1.0-UV.y,1.5)*light_shafts;
    float grain=fract(sin(dot(floor(UV/TEXTURE_PIXEL_SIZE)+floor(visual_time*12.0),vec2(12.9898,78.233)))*43758.5453)-.5;
    COLOR=vec4((base.rgb+glow*bloom*.25*bloom_strength+vec3(.76,.85,.66)*rays)*shade+grain*film_grain*.025,base.a);
}
