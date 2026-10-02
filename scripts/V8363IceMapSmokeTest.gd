extends "res://scripts/V83UpgradeTestBase.gd"
func _init() -> void: run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10)
	main._build_combat_screen();await settle()
	var terrain=main.combat_labels.terrain
	check(terrain.map_root.name=='IceCavern_Map','default field loads live ice cavern')
	check(terrain.world.get_node('CarvedStoneArena') is MeshInstance3D,'arena is a real mesh')
	check(terrain.world.get_node('CarvedStoneArena/ArenaCollision') is StaticBody3D,'floor has physical collision')
	check(terrain.world.get_node('CarvedFrozenDoubleDoorFace') is MeshInstance3D,'carved door is placed in 3D')
	check(terrain.actors.size()==main.hero_map_sprites.size()+main.enemy_wave_sprites.size(),'all combat actors represented in 3D')
	check(main.field_navigation.uses_3d_layout,'open clearing uses matching navigation')
	for p in [Vector2(1,1),Vector2(16,10),Vector2(31,19)]:
		check(terrain.local_to_world(terrain.project_world(p)).distance_to(p)<.001,'camera ground round trip '+str(p))
	for i in 40:main._advance_auto_hunt(.1)
	main.combat_running=false;await settle()
	var hp: Dictionary=main.hero_battle_state.duplicate(true)
	var wave: Array=main.enemy_wave.duplicate(true)
	main.presentation_options.orientation='landscape';preload('res://scripts/DisplayOrientation.gd').apply(main,false);root.size=Vector2i(1280,720)
	await settle();main._apply_portrait_resize();await settle()
	check(main.hero_battle_state==hp and main.enemy_wave==wave,'rotation preserves complete battle state')
	for i in main.hero_map_sprites.size():
		var id: String=str(main.deployed_heroes[i].id)
		var projected: Vector2=terrain.position+terrain.project_world(main._hero_field_position(id))
		check(main.hero_map_sprites[i].position.distance_to(projected)<.01,'HUD actor projection updates while paused')
		check(main.hero_hp_bars[id].position.distance_to(projected+Vector2(-16,3))<.01,'HP anchors match new viewport')
	main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle();await settle()
	var raid=main.content_root.get_node('PortraitRaidView');terrain=raid.battlefield_3d
	check(terrain.map_root.name=='IceCavern_Map','raid loads real ice cavern')
	check(raid.stage.get_global_rect().end.y<root.size.y-250,'raid stage fits above party dock')
	for p in [Vector2(300,320),Vector2(635,397),Vector2(800,470)]:
		var visual: Vector2=terrain.project_world(terrain.raid_to_world(p))
		var overlay: Vector2=raid.arena.position+p*raid.arena.scale
		check(visual.distance_to(overlay)<.02,'raid effects and 3D floor share projection')
	await dispose(main);done('v8363_ice_map')
