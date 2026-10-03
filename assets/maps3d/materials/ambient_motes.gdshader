shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color=vec4(.4,.8,1.,1.);
uniform float drift=.1;
varying float shimmer;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float phase=p.x*1.31+p.z*.73;
 VERTEX.x+=sin(TIME*drift+phase)*.35;
 VERTEX.y+=sin(TIME*drift*.8+phase*1.7)*.25;
 shimmer=.45+.55*pow(.5+.5*sin(TIME*.7+phase),2.);
}
void fragment(){ALBEDO=tint.rgb*shimmer;EMISSION=tint.rgb*shimmer*.8;}
