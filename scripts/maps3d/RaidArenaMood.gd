extends Node3D
## Presentation-only phase response, restricted to peripheral crystal lights.
var current_phase:=1
var current_enraged:=false
var lamps: Array[OmniLight3D]=[]
var energies: PackedFloat32Array=[]
var crystals: Array[ShaderMaterial]=[]
func _ready() -> void:
	for node in find_children('*','OmniLight3D',true,false):
		lamps.append(node);energies.append(node.light_energy)
	var copies: Dictionary={}
	for node in find_children('*','GeometryInstance3D',true,false):
		var material: Material=node.material_override
		if not material is ShaderMaterial or not material.shader.resource_path.ends_with('raid_crystal.gdshader'):continue
		var id:=material.get_instance_id()
		if not copies.has(id):
			copies[id]=material.duplicate();crystals.append(copies[id])
		node.material_override=copies[id]
func set_battle_mood(phase: int,enraged: bool) -> void:
	phase=clampi(phase,1,3)
	if phase==current_phase and enraged==current_enraged:return
	current_phase=phase;current_enraged=enraged
	var surge:=float(phase-1)*.18+(.20 if enraged else 0.)
	for i in lamps.size():lamps[i].light_energy=energies[i]*(1.+surge)
	for material in crystals:material.set_shader_parameter('surge',surge)
