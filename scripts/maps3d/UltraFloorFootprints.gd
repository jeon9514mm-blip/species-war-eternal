extends Node3D
## Visual walking traces: one draw, 50 reused instances, no simulation writes.
const CAPACITY:=50
const LIFETIME:=6.0
const SAMPLE_INTERVAL:=.14
var field: Control
var prints: MultiMeshInstance3D
var _marks: Array[Dictionary]=[]
var _last_positions: Dictionary={}
var _next_slot:=0
var _sample_clock:=0.0
var _side:=false
func _ready() -> void:
	name='UltraFloorFootprints'
	prints=MultiMeshInstance3D.new();prints.name='FootprintPool50'
	var mesh:=PlaneMesh.new();mesh.size=Vector2(.34,.50)
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data=true;multimesh.mesh=mesh;multimesh.instance_count=CAPACITY
	prints.multimesh=multimesh
	var material:=ShaderMaterial.new();material.shader=preload('res://shaders/UltraFloorFootprint.gdshader')
	prints.material_override=material;prints.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in CAPACITY:
		multimesh.set_instance_custom_data(index,Color(0,0,0,0));_marks.append({})
	add_child(prints);process_priority=103
func emit_step(point: Vector2,direction: Vector2) -> void:
	if direction.length_squared()<.000001:return
	var along:=direction.normalized();var cross:=Vector2(-along.y,along.x)
	_side=not _side;point+=cross*(.08 if _side else -.08)
	var angle: float=-along.angle()+PI*.5
	var scale: float=1.5 if is_instance_valid(field) and field.raid_mode else 1.0
	var basis:=Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale)
	prints.multimesh.set_instance_transform(_next_slot,Transform3D(basis,Vector3(point.x,.023,point.y)))
	prints.multimesh.set_instance_custom_data(_next_slot,Color(.22,0,0,0))
	_marks[_next_slot]={'age':0.0};_next_slot=(_next_slot+1)%CAPACITY
func _hero_positions() -> Dictionary:
	var positions: Dictionary={}
	if field.raid_mode:
		if not is_instance_valid(field.raid_view):return positions
		for id in field.raid_view.hero_actors:
			var source=field.raid_view.hero_actors[id]
			if is_instance_valid(source) and source.state=='walk' and float(field.game.hero_battle_state.get(id,{}).get('hp',0))>0:
				positions[id]=field.raid_to_world(source.position)
	else:
		for i in mini(field.game.hero_map_sprites.size(),field.game.deployed_heroes.size()):
			var source=field.game.hero_map_sprites[i];var id:=str(field.game.deployed_heroes[i].id)
			if is_instance_valid(source) and source.state=='walk' and float(field.game.hero_battle_state.get(id,{}).get('hp',0))>0:
				positions[id]=field.display_world(source,field.game._hero_field_position(id))
	return positions
func _process(delta: float) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game):return
	visible=field.presentation_visible and field.game.combat_effects_enabled and str(field.game.presentation_options.get('performance','balanced'))!='battery'
	if not visible or not field.visual_running():return
	var seconds: float=maxf(0,delta)*field.visual_speed()
	_sample_clock+=seconds
	if _sample_clock<SAMPLE_INTERVAL:return
	seconds=_sample_clock;_sample_clock=0.0
	for i in CAPACITY:
		if _marks[i].is_empty():continue
		_marks[i].age+=seconds
		var fade: float=clampf(1.0-float(_marks[i].age)/LIFETIME,0,1)
		prints.multimesh.set_instance_custom_data(i,Color(fade*.22,0,0,0))
		if fade<=0:_marks[i]={}
	var positions:=_hero_positions()
	for id in positions:
		var point: Vector2=positions[id]
		if _last_positions.has(id):
			var direction: Vector2=point-_last_positions[id]
			if direction.length_squared()<.12:continue
			emit_step(point,direction)
		_last_positions[id]=point
	for id in _last_positions.keys():
		if not positions.has(id):_last_positions.erase(id)
