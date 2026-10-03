shader_type spatial;
uniform vec4 tint : source_color=vec4(.10,.56,.72,1.);
uniform float surge : hint_range(0.,1.)=0.;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 float facet=.72+sin(local.y*7.+local.x*11.)*.08;
 float fresnel=pow(1.-max(0.,dot(normalize(NORMAL),normalize(VIEW))),2.);
 ALBEDO=tint.rgb*(.35+facet*.35);ROUGHNESS=.24;METALLIC=.12;SPECULAR=.65;
 EMISSION=tint.rgb*(.18+fresnel*.58)*(1.+surge);
}
