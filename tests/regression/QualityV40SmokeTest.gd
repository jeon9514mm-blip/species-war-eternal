extends 'res://tests/support/V83UpgradeTestBase.gd'
const STYLE=preload('res://scripts/combat/CombatNumberStyle.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10)
	main.combat_effects_enabled=true
	main._build_combat_screen();await settle();main.combat_running=false
	var field=main.combat_labels.terrain;field.set_process(false)
	var state: Dictionary=main.hero_battle_state.duplicate(true)
	var positions: Dictionary=main.party_movement.positions.duplicate(true)
	var rng: int=main.loot_rng.state;var wallet:=economic(main)
	check(STYLE.FONT.resource_path.ends_with('Outfit-ExtraBold.ttf'),'real bundled Outfit ExtraBold is used')
	check(STYLE.FONT.get_string_size('92 34 1,234',HORIZONTAL_ALIGNMENT_LEFT,-1,28).x>0,'new font has readable exact numerals')
	check(field.rune_ground.stone_material.get_shader_parameter('moss_rune')==Color('#a8b89e') and field.rune_ground.stone_material.get_shader_parameter('bronze_rune')==Color('#c4a484'),'ground uses the supplied moss and bronze colors')
	for mode in ['balanced','battery','balanced']:
		main.presentation_options.performance=mode;field.apply_render_profile();await settle()
		field._process(0)
		var actor_paint=field.actors[main.hero_map_sprites[0].get_instance_id()].get_node('HuntFramePilot')
		check(actor_paint.cast_shadow==(GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mode=='balanced' else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),'real painted shadows follow performance profile '+mode)
		check(is_equal_approx(field.viewport_3d.scaling_3d_scale,1.5 if mode=='balanced' else 1.0),'supersampling follows performance profile '+mode)
		for point in [Vector2(0,0),Vector2(16,10),Vector2(32,20)]:
			check(field.local_to_world(field.project_world(point)).distance_to(point)<.002,'render quality preserves tap projection '+mode)
	main.combat_effects_enabled=false;field._process(0)
	check(field.actors[main.hero_map_sprites[0].get_instance_id()].get_node('HuntFramePilot').cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,'effects-off disables optional painted directional shadows')
	main.combat_effects_enabled=true
	check(state==main.hero_battle_state and positions==main.party_movement.positions and rng==main.loot_rng.state and wallet==economic(main),'quality settings cannot mutate simulation')
	field._process(0)
	var source=main.hero_map_sprites[0];source.set_process(false);source.speed_scale=1.0
	var pilot=field.actors[source.get_instance_id()].get_node('HuntFramePilot')
	pilot.effects_enabled=true;pilot.timeline.release('attack_1',.15)
	pilot.present(field.camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
	var contact: Mesh=pilot.mesh
	check(pilot._echoes.layers.size()==2 and pilot._echoes.layers[0].visible and pilot._echoes.layers[1].visible,'real contact creates two painted echoes')
	check(pilot._echoes.layers[0].mesh==contact,'echo uses the full current original contact pose')
	pilot.present(field.camera,1.55,Color.WHITE,.05,true,Vector2.ZERO,{},false)
	check(pilot._echoes.layers[0].mesh==contact,'recovery does not change the captured echo pose')
	var alpha: float=pilot._echoes.layers[0].material_override.get_shader_parameter('opacity')
	var lift: Vector3=pilot.position;var clock: float=pilot._visual_time
	for i in 5:pilot.present(field.camera,1.55,Color.WHITE,.1,false,Vector2.ZERO,{},false)
	check(pilot._visual_time==clock and pilot.position==lift and pilot._echoes.layers[0].material_override.get_shader_parameter('opacity')==alpha,'pause freezes body lift and echo fade')
	pilot.present(field.camera,1.55,Color.WHITE,.16,true,Vector2.ZERO,{},false)
	check(not pilot._echoes.layers[0].visible and not pilot._echoes.layers[1].visible,'echoes expire after the short contact trail')
	pilot.timeline.hit(Vector2.RIGHT);pilot.present(field.camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
	check(float(pilot.material_override.get_shader_parameter('hit_flash'))>.5,'actual hit produces a brief whole-body highlight')
	pilot.present(field.camera,1.55,Color.WHITE,.05,true,Vector2.ZERO,{},false)
	check(float(pilot.material_override.get_shader_parameter('hit_flash'))==0,'highlight expires rather than bleaching the painting')
	pilot.effects_enabled=false;pilot.timeline.release('skill',.15);pilot.present(field.camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
	check(not pilot._echoes.layers[0].visible and not pilot._echoes.layers[1].visible,'effects-off hides optional echoes immediately')
	check(is_equal_approx(pilot.basis.x.length(),pilot.basis.y.length()),'quality effects preserve uniform whole-body anatomy')
	check(state==main.hero_battle_state and positions==main.party_movement.positions and rng==main.loot_rng.state and wallet==economic(main),'body effects change no combat state or economy')
	await dispose(main);done('quality_v40')
