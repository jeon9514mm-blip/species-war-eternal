extends SceneTree
var checks := 0
var failures: Array[String] = []
var details: Array = []
var main: Node
func _init() -> void:
	run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	details.append({'check':label,'passed':value})
	if not value:
		failures.append(label)
		push_error(label)
func fixture(node: Node, faction: String, count: int) -> void:
	node.set_physics_process(false)
	node.selected_faction=faction
	node.idle_stage=25
	node.idle_stage_kills=0
	node._offline_checked=true
	node.combat_effects_enabled=false
	node.current_zone_id='gray_meadow'
	node.hero_progress={}
	node.hero_equipment={}
	node.hero_equipment_rarity={}
	node.hero_equipment_names={}
	node.hero_equipment_sets={}
	node.hero_skill_tree={}
	node.hero_breakthrough={}
	node.hero_ascension={}
	node.pet_progress={}
	node.unclaimed_gold=0;node.unclaimed_xp=0
	node.deployed_heroes=node._hero_roster_for_faction().slice(0,count)
	node._setup_hero_progress(node._hero_roster_for_faction())
	node._build_combat_screen()
	node.loot_rng.seed=350091
func combat_state(node: Node) -> Dictionary:
	var heroes: Dictionary={}
	for id in node.hero_battle_state:
		var state: Dictionary=node.hero_battle_state[id]
		heroes[id]={'hp':state.get('hp',0),'max_hp':state.get('max_hp',0),'attack':state.get('attack',0),'defense':state.get('defense',0),'ultimate':state.get('ultimate',0)}
	return {'heroes':heroes,'kills':node.combat_kills,'gold':node.unclaimed_gold,'xp':node.unclaimed_xp,'enemy_hp':node.enemy_hp,'stage':node.idle_stage,'step':node.idle_stage_kills,'position':node.expedition_position}
func run() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.size=Vector2i(720,1560)
	check(int(ProjectSettings.get_setting('display/window/handheld/orientation'))==1,'project locks portrait orientation')
	check(str(ProjectSettings.get_setting('application/run/main_scene'))=='res://scenes/PortraitMain.tscn','app starts portrait scene, original scene retained for regression')
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://portrait-regression.json'
	root.add_child(main)
	await process_frame
	fixture(main,'aurelia',3)
	await process_frame
	check(main.deployed_heroes.size()==3,'v32 party preserved')
	check(main.combat_field_rect.size.y>main.combat_field_rect.size.x,'combat field truly portrait, not a letterboxed landscape canvas')
	check(main.portrait_hud.slot_row.get_child_count()>=10,'ten visible hero/locked slots')
	for id in ['leonhardt','mira','elisia']:
		check(main.portrait_hud.bars.has(id),'HP/ultimate widgets for '+id)
		var icon: TextureRect=main.portrait_hud.find_child('Portrait_'+id,true,false)
		check(icon!=null and icon.texture==main._combat_portrait_texture(id),'original v32 portrait routed for '+id)
	var id := 'leonhardt'
	main.hero_battle_state[id]['hp']=int(main.hero_battle_state[id]['max_hp']*.25)
	main.hero_battle_state[id]['ultimate']=87.0
	main.portrait_hud.refresh()
	check(absf(main.portrait_hud.bars[id]['hp'].value-25)<1,'display uses real hero HP')
	check(main.portrait_hud.bars[id]['ultimate'].value==87.0,'display uses real hero ultimate')
	var before: bool=main.combat_running
	main.portrait_hud._toggle_auto()
	check(main.combat_running!=before,'AUTO button invokes existing pause command')
	main.portrait_hud._toggle_auto()
	check(main.combat_running==before,'AUTO resumes without changing AI mode')
	for dims: Vector2i in [Vector2i(720,1280),Vector2i(720,1440),Vector2i(720,1560)]:
		var state_before:=combat_state(main)
		var encounter: int=main.hunt_ai.encounter_id
		root.size=dims
		for f in 4:await process_frame
		check(state_before==combat_state(main),'resize preserves HP/XP/rewards/position '+str(dims))
		check(encounter==main.hunt_ai.encounter_id,'resize does not respawn encounters '+str(dims))
		var nav: Control=main.portrait_hud.get_node('PortraitNavigation')
		check(nav.position.y+nav.size.y<=float(dims.y)+1,'navigation inside screen '+str(dims))
		check(main.portrait_hud.slot_row.position.y+main.portrait_hud.slot_row.size.y<nav.position.y,'party slots do not overlap bottom navigation '+str(dims))
		check(main.combat_field_rect.size.y>main.combat_field_rect.size.x,'portrait field maintained '+str(dims))
	# Check identical combat outcomes with same v32 code + seed. Only the view differs.
	for faction in ['aurelia','noxfera']:
		var reference=preload('res://scenes/Main.tscn').instantiate()
		reference.save_state_path='user://portrait-reference-'+faction+'.json'
		root.add_child(reference)
		await process_frame
		fixture(reference,faction,5);fixture(main,faction,5)
		for i in 200:
			reference._advance_auto_hunt(.05)
			main._advance_auto_hunt(.05)
		if combat_state(reference)!=combat_state(main):
			print('REFERENCE ',JSON.stringify(combat_state(reference)))
			print('PORTRAIT ',JSON.stringify(combat_state(main)))
		check(combat_state(reference)==combat_state(main),'same seeded live combat outcome as untouched v32: '+faction)
		check(main.roaming_hunt.distance_walked>0,'automatic pursuit continues '+faction)
		reference._clear_screen();reference.free()
	# Secondary screen paths retain callbacks and can return to combat.
	for entry in [['_build_lobby_screen','lobby'],['_build_hero_select_screen','hero_select'],['_build_inventory_screen','inventory'],['_build_meta_hub_screen','meta_hub'],['_build_summon_screen','summon'],['_build_world_map_screen','world_map']]:
		main.call(str(entry[0]));await process_frame
		check(main.active_screen==entry[1],'portrait menu opens '+str(entry[1]))
	main._build_combat_screen();await process_frame
	check(is_instance_valid(main.portrait_hud),'returns from menus to live portrait HUD')
	# Ten slots / compact bars in the fully grown party.
	fixture(main,'aurelia',10)
	await process_frame
	check(main.portrait_hud.bars.size()==10,'all ten v32 heroes have portrait HUD health bars')
	for hero_id in main.portrait_hud.bars:
		check(main.portrait_hud.bars[hero_id]['hp'].size.y<=15,'compact HP bar height '+str(hero_id))
	# Original raid remains playable in portrait, with the original timer stopped
	# for deterministic simulation in this test fixture only.
	main._build_raid_screen()
	await process_frame
	var raid: Control=main.content_root.get_node_or_null('PortraitRaidView')
	check(raid!=null,'portrait-native raid arena installed')
	main._start_raid()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	check(main.raid_running,'original raid command starts from portrait view')
	for i in 40:main._advance_raid_encounter(.05)
	if raid!=null:raid.refresh()
	check(main.raid_elapsed>0,'original raid simulation advances')
	check(main.raid_boss_hp<main.raid_boss_max_hp,'original raid applies damage')
	main._build_faction_war_screen()
	await process_frame
	var war: WorldWarScreen
	for child in main.content_root.get_children():
		if child is WorldWarScreen:war=child
	check(war!=null,'original war screen retained')
	if war!=null:
		var map: Control=war.get_node('WarMapPanel')
		var command: Control=war.get_node('WarCommandPanel')
		check(map.position.x+map.size.x<=720.1,'portrait war map fits width')
		check(command.position.y>=map.position.y+map.size.y,'war commands below map')
		check(command.position.y+command.size.y<1560-114,'war commands above bottom menu')
		check(war.client_session==main.world_war_client_session,'original authoritative war session unchanged')
	# Direct original HeroScreens detail callbacks still receive portrait chrome.
	preload('res://scripts/HeroScreens.gd').detail(main,'leonhardt')
	for f in 4:await process_frame
	check(main.content_root.has_meta('portrait_ready'),'direct original detail rebuilds stay portrait')
	# Portrait-native replacement for the legacy landscape camera boundary check.
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		main.current_zone_id=zone
		main._build_combat_screen()
		await process_frame
		var terrain: Control=main.combat_labels['terrain']
		var anchor: Vector2=main._combat_camera_anchor()-main.combat_field_rect.position
		var before_camera: Vector2=anchor/main._combat_map_scale()
		var after_camera: Vector2=(main.combat_field_rect.size-anchor)/main._combat_map_scale()
		for request: Vector2 in [Vector2(-100,-100),Vector2.ZERO,Vector2(16,10),Vector2(32,20),Vector2(100,100)]:
			var camera: Vector2=main._clamp_combat_camera(request)
			check(terrain.art_world_rect().grow(.001).encloses(Rect2(camera-before_camera,before_camera+after_camera)),'portrait scenery covers edge camera '+zone+' '+str(request))
		main._update_combat_camera(0.0)
		var point:=Vector2(16,10)
		var actor: Vector2=main._map_world_position(point)
		var ground: Vector2=main.combat_field_rect.position+terrain._map_point(point)
		check(actor.distance_to(ground)<.001,'same actor/terrain coordinates in portrait '+zone)
	var result: Dictionary={'checks':checks,'passed':checks-failures.size(),'failures':failures,'details':details,'engine':Engine.get_version_info()['string'],'scope':'desktop headless gameplay and presentation state; not Android APK'}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with('--report='):
			var file:=FileAccess.open(argument.trim_prefix('--report='),FileAccess.WRITE)
			if file == null:
				check(false,'regression report can be written')
			else:
				file.store_string(JSON.stringify(result,'\t'));file.close()
	main._clear_screen();main.free()
	print('PORTRAIT REGRESSION ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
