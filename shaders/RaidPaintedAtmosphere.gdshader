shader_type canvas_item;
render_mode unshaded;
uniform vec4 mist_color : source_color = vec4(0.45,0.70,0.85,1.0);
uniform float visual_time = 0.0;
uniform float atmosphere_strength = 0.035;
varying vec4 vertex_modulation;
void vertex() { vertex_modulation = COLOR; }
void fragment() {
    vec4 art = texture(TEXTURE,UV);
    float side = pow(abs(UV.x-0.5)*2.0,3.0);
    float edge = smoothstep(0.30,0.95,length((UV-0.5)*vec2(1.2,0.8)));
    float haze = (sin(UV.x*17.0+visual_time*0.12)+sin(UV.y*23.0-visual_time*0.08))*0.25+0.5;
    float distant = 1.0-smoothstep(0.20,0.48,UV.y);
    vec3 paint = art.rgb*(1.0-edge*0.10);
    paint = mix(paint,mist_color.rgb,atmosphere_strength*haze*(distant+side*0.35));
    COLOR = vec4(paint,art.a)*vertex_modulation;
}
