extends 'res://tests/support/V83UpgradeTestBase.gd'
const DESIGN=preload('res://scripts/maps3d/RaidEncounterArena.gd')
const FIELD=preload('res://scripts/raid/RaidBattlefield.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10)
	var identities: Dictionary={};var signatures: Dictionary={}
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		root.size=Vector2i(1280,720);main.selected_raid_id=zone;main._build_raid_screen()
		await settle();await settle()
		var view=main.content_root.get_node('PortraitRaidView');var field=view.battlefield_3d
		var architecture: Node3D=field.world.get_node('RaidEncounterArena')
		var design: Dictionary=architecture.get_meta('encounter_design');identities[design.id]=true
		check(design.combat_rect.is_equal_approx(DESIGN.combat_rect()),'dedicated floor follows actual raid bounds '+zone)
		check(design.dynamic_lights==0 and design.static_mesh_count<=45,'fixed static map budget '+zone)
		check(architecture.find_children('*','Light3D',true,false).is_empty(),'no per-prop light/shadow passes '+zone)
		check(not field.world.get_node('EnvironmentModel').visible,'hunt-sized columns are replaced '+zone)
		var floor: MeshInstance3D=field.world.get_node('PBRStoneSlabs1024')
		check(floor.visible and is_zero_approx(floor.position.y),'reachable combat feet retain y zero '+zone)
		var material: ShaderMaterial=floor.material_override
		check(material.shader.resource_path=='res://shaders/RaidArenaPBR.gdshader','dedicated PBR court is actually rendered '+zone)
		check(material.get_shader_parameter('stone_art').get_size()==Vector2(1024,1024),'reuses the existing 1024 stone asset '+zone)
		check(Vector2(material.get_shader_parameter('arena_min')).distance_to(field.raid_to_world(FIELD.FLOOR.position))<.001,'surface edge matches the movement rectangle '+zone)
		var landmark: String={'gray_meadow':'SanctuaryTablet','forgotten_mine':'MineGantries','moonrest_forest':'CrescentShrine'}[zone]
		check(architecture.get_node_or_null(landmark)!=null,'zone-specific authored landmark '+zone)
		signatures[landmark]=true
		for node: MeshInstance3D in architecture.find_children('*','MeshInstance3D',true,false):
			check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,'architecture does not add a shadow pass '+str(node.name))
			var box:=node.get_aabb();var raised_min:=node.position.y+box.position.y
			var point:=Vector2(node.position.x,node.position.z)
			# Foundation/lip may extend below the court, but tall silhouettes never
			# project from an actual reachable combat point.
			if raised_min+.10>.20:check(not DESIGN.combat_rect().grow(.30).has_point(point),'raised prop lies outside the combat floor '+str(node.name))
		var before:=economic(main);var rng: int=main.loot_rng.state
		var hp: Dictionary=main.hero_battle_state.duplicate(true);var positions: Dictionary=main.raid_positions.duplicate()
		for mode in ['battery','quality','balanced']:
			main.presentation_options.performance=mode;field.apply_render_profile();field._process(0)
			check(material==floor.material_override,'quality changes retain the dedicated map '+zone+' '+mode)
			check(material.get_shader_parameter('parallax_steps')==(8 if mode=='quality' else 4),'quality retains bounded PBR traversal '+zone+' '+mode)
		check(economic(main)==before and main.loot_rng.state==rng and main.hero_battle_state==hp and main.raid_positions==positions,'arena changes never write gameplay '+zone)
		for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1560,720)]:
			root.size=dimensions;await settle();await settle()
			field=main.content_root.get_node('PortraitRaidView').battlefield_3d
			for point: Vector2 in [FIELD.FLOOR.position,FIELD.FLOOR.end,Vector2(214,486),Vector2(824,280),FIELD.ENTRY]:
				var projected: Vector2=field.project_world(field.raid_to_world(point))
				check(Rect2(Vector2.ZERO,field.size).has_point(projected),'dedicated arena reserves complete floor '+zone+' '+str(dimensions))
				check(field.local_to_world(projected).distance_to(field.raid_to_world(point))<.002,'dedicated map touch inverts to the same floor '+zone)
	check(identities.size()==3 and signatures.size()==3,'all three encounters have distinct authored silhouettes')
	await dispose(main);done('RAID_DEDICATED_ARENA')
