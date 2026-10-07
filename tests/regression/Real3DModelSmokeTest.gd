extends 'res://tests/support/V83UpgradeTestBase.gd'
const CATALOG=preload('res://scripts/art/Model3DCatalog.gd')
const PILOT=preload('res://scripts/art/Model3DPilot.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var catalog=CATALOG.new();check(catalog._entries.size()==46,'all 30 heroes, 13 monsters and 3 bosses exist')
	var heroes:=0
	for entry: Dictionary in catalog._entries.values():
		var model=(load(str(entry.path)) as PackedScene).instantiate();root.add_child(model)
		var skeletons=model.find_children('*','Skeleton3D',true,false)
		check(skeletons.size()==1 and skeletons[0].get_bone_count()>=4,str(entry.id)+' has real bones')
		var players=model.find_children('*','AnimationPlayer',true,false)
		check(players.size()==1,str(entry.id)+' has an animation player')
		for action in entry.animations:check(players[0].has_animation(action),str(entry.id)+' has '+str(action))
		var meshes=model.find_children('*','MeshInstance3D',true,false)
		check(not meshes.is_empty() and meshes[0].skin!=null,str(entry.id)+' has weighted volume geometry')
		var bounds: AABB=meshes[0].mesh.get_aabb()
		check(bounds.size.x>.15 and bounds.size.y>.15 and bounds.size.z>.15,str(entry.id)+' is volumetric on all three axes')
		if entry.hero:heroes+=1
		model.free()
	check(heroes==30,'complete hero roster')
	var main=await make_main('aurelia',10);main._build_combat_screen();await settle();main.combat_running=false
	var field=main.combat_labels.terrain;field.set_process(false);field.real_models_enabled=true;field._process(0);field._process(0)
	var hp: Dictionary=main.hero_battle_state.duplicate(true);var positions: Dictionary=main.party_movement.positions.duplicate(true)
	var rng: int=main.loot_rng.state;var wallet:=economic(main)
	var uniform_height:=-1.0
	for source in main.hero_map_sprites:
		var pilot=field.actors[source.get_instance_id()].get_node('Model3DPilot')
		check(pilot.debug_snapshot().renderer=='real_skinned_3d','actual game renders real models')
		check(source.visibility_layer==0 and field.actors[source.get_instance_id()].texture==null,'old paintings are not drawn')
		var height: float=pilot.scale.y*float(pilot.entry.native_height)*field.camera.global_basis.y.y
		if uniform_height<0:uniform_height=height
		check(is_equal_approx(height,uniform_height),'all heroes have one projected standing height')
	var source=main.hero_map_sprites[0];source.set_process(false);source.speed_scale=1
	var pilot=field.actors[source.get_instance_id()].get_node('Model3DPilot')
	pilot.timeline.release('attack_1',.15);pilot.present(field.camera,2.05,Color.WHITE,0,true,Vector2.ZERO,{},false)
	check(is_equal_approx(pilot.debug_snapshot().phase,.44),'attack contact follows the real release')
	var held=pilot.debug_snapshot();var bones=pilot._model.find_children('*','Skeleton3D',true,false)[0]
	var pose: Transform3D=bones.get_bone_pose(3)
	for i in 10:pilot.present(field.camera,2.05,Color.WHITE,.1,false,Vector2.ZERO,{},false)
	check(pilot.debug_snapshot().time==held.time and bones.get_bone_pose(3)==pose,'pause freezes actual bones')
	pilot.present(field.camera,2.05,Color.WHITE,0,true,Vector2.ZERO,{},true)
	check(pilot.debug_snapshot().action=='death','death uses real HP state')
	pilot.present(field.camera,2.05,Color.WHITE,0,false,Vector2.ZERO,{},false)
	check(pilot.debug_snapshot().action!='death','revival clears death while paused')
	check(main.hero_battle_state==hp and main.party_movement.positions==positions and main.loot_rng.state==rng and economic(main)==wallet,'3D presentation never mutates gameplay or economy')
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		for suffix in ['hunt','raid']:
			var map=(load('res://assets/models3d-v1/environments/'+zone+'_'+suffix+'.glb') as PackedScene).instantiate()
			check(map.find_children('*','MeshInstance3D',true,false).size()>0,zone+' '+suffix+' has modeled architecture');map.free()
	await dispose(main);done('real_3d_models')
