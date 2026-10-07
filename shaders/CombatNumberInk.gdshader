shader_type canvas_item;
render_mode unshaded;
uniform vec4 ink_top : source_color = vec4(1.0);
uniform vec4 ink_bottom : source_color = vec4(1.0,0.75,0.25,1.0);
uniform float label_height = 40.0;
varying float local_y;
void vertex() { local_y = VERTEX.y; }
void fragment() {
    // Dark outlines and shadows keep their ink; only white glyph faces change.
    vec4 paint = COLOR;
    float face = smoothstep(0.35,0.70,max(paint.r,max(paint.g,paint.b)));
    float gradient = smoothstep(0.18,0.90,local_y/max(label_height,1.0));
    vec3 ink = mix(ink_top.rgb,ink_bottom.rgb,gradient);
    COLOR = vec4(mix(paint.rgb,ink,face),paint.a);
}
