shader_type sky;
// Reusable irradiance/reflection sky: stars and moon remain above the horizon.
uniform vec3 zenith : source_color=vec3(.075,.105,.16);
uniform vec3 horizon : source_color=vec3(.44,.53,.58);
uniform vec3 moon_direction=vec3(.45,.72,-.52);
float sky_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void sky() {
    vec3 direction=normalize(EYEDIR);
    float up=clamp(direction.y,0.0,1.0);
    vec3 color=mix(horizon,zenith,pow(up,.55));
    vec2 star_uv=vec2(atan(direction.z,direction.x)/6.2831853+.5,asin(direction.y)/3.14159265+.5)*vec2(192.0,96.0);
    vec2 cell=floor(star_uv);vec2 local=fract(star_uv)-.5;
    float seed=sky_hash(cell);float stars=step(.984,seed)*exp(-dot(local,local)*115.0)*smoothstep(.04,.32,up);
    float alignment=dot(direction,normalize(moon_direction));
    float moon=smoothstep(.99905,.99945,alignment)*smoothstep(.03,.08,up);
    float halo=exp((alignment-1.0)*420.0)*.035;
    color+=vec3(.75,.84,1.0)*(stars*.65+moon*.9+halo);
    COLOR=mix(vec3(.105,.13,.14),color,smoothstep(-.08,.02,direction.y));
}
