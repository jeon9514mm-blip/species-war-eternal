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
	check(field.rune_ground.stone_material.get_shader_parameter('moss')==Color('#a8b89e') and field.rune_ground.stone_material.get_shader_parameter('bronze')==Color('#e8c99a'),'ground uses the supplied moss and bright bronze rune colors')
	for mode in ['balanced','battery','quality','balanced']:
		main.presentation_options.performance=mode;field.apply_render_profile();await settle()
		field._process(0)
		var actor_paint=field.actors[main.hero_map_sprites[0].get_instance_id()].get_node('HuntFramePilot')
		check(actor_paint.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,'baked painted contact shadows retain the bounded profile '+mode)
		var hair_shadow: int=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mode=='quality' and actor_paint.secondary_lod==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check(actor_paint._hair.cast_shadow==hair_shadow,'actual hair shadow follows render profile and LOD '+mode)
		check(is_equal_approx(field.viewport_3d.scaling_3d_scale,.85 if mode=='balanced' else 1.0),'render resolution follows performance profile '+mode)
		for point in [Vector2(0,0),Vector2(16,10),Vector2(32,20)]:
			check(field.local_to_world(field.project_world(point)).distance_to(point)<.002,'render quality preserves tap projection '+mode)
	main.combat_effects_enabled=false;field._process(0)
	check(field.actors[main.hero_map_sprites[0].get_instance_id()].get_node('HuntFramePilot').cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,'effects-off disables optional painted directional shadows')
	main.combat_effects_enabled=true
	check(state==main.hero_battle_state and positions==main.party_movement.positions and rng==main.loot_rng.state and wallet==economic(main),'quality settings cannot mutate simulation')
	field._process(0)
	var source=main.hero_map_sprites[0];source.set_process(false);source.speed_scale=1.0
	var pilot=field.actors[source.get_instance_id()].get_node('HuntFramePilot')
	pilot.effects_enabled=true;pilot.echo_layers=5;pilot.timeline.release('attack_1',.15)
	pilot.present(field.camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
	var contact: Mesh=pilot.mesh
	check(pilot._echoes.multimesh.instance_count==5 and pilot._echoes.visible_count()==5,'real contact creates five native painted echo instances')
	check(pilot._echoes.multimesh.mesh==contact,'echo uses the full current original contact pose')
	pilot.present(field.camera,1.55,Color.WHITE,.05,true,Vector2.ZERO,{},false)
	check(pilot._echoes.multimesh.mesh==contact,'recovery does not change the captured echo pose')
	var alpha: float=pilot._echoes.instance_opacity(0)
	var lift: Vector3=pilot.position;var clock: float=pilot._visual_time
	for i in 5:pilot.present(field.camera,1.55,Color.WHITE,.1,false,Vector2.ZERO,{},false)
	check(pilot._visual_time==clock and pilot.position==lift and pilot._echoes.instance_opacity(0)==alpha,'pause freezes body lift and native echo fade')
	pilot.present(field.camera,1.55,Color.WHITE,.36,true,Vector2.ZERO,{},false)
	check(pilot._echoes.visible_count()==0 and not pilot._echoes.instance.visible,'echo instances expire after the bounded .40 second trail')
	pilot.timeline.hit(Vector2.RIGHT);pilot.present(field.camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
	check(float(pilot.material_override.get_shader_parameter('hit_flash'))>.5,'actual hit produces a brief whole-body highlight')
	pilot._flash_started_us=Time.get_ticks_usec()-41000;pilot.present(field.camera,1.55,Color.WHITE,.05,true,Vector2.ZERO,{},false)
	check(float(pilot.material_override.get_shader_parameter('hit_flash'))==0,'highlight expires rather than bleaching the painting')
	pilot.effects_enabled=false;pilot.timeline.release('skill',.15);pilot.present(field.camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
	check(pilot._echoes.visible_count()==0 and not pilot._echoes.instance.visible,'effects-off hides optional echo instances immediately')
	check(is_equal_approx(pilot.basis.x.length(),pilot.basis.y.length()),'quality effects preserve uniform whole-body anatomy')
	check(state==main.hero_battle_state and positions==main.party_movement.positions and rng==main.loot_rng.state and wallet==economic(main),'body effects change no combat state or economy')
	await dispose(main);done('quality_v40')
