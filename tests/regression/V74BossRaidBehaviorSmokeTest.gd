extends SceneTree
const DESIGN := preload('res://scripts/raid/RaidBossDesign.gd')
const FIELD := preload('res://scripts/raid/RaidBattlefield.gd')
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error('V74 boss raid: '+label)

func _run() -> void:
	_test_pattern_rotation()
	_test_new_footprints()
	await _test_target_personality()
	await _test_role_formation()
	print('V74BossRaidBehaviorSmokeTest: %d checks, %d failures'%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_pattern_rotation() -> void:
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		for phase in [1,2,3]:
			var primary: Dictionary=DESIGN.pattern(zone,phase,0)
			var alternate: Dictionary=DESIGN.pattern(zone,phase,1)
			check(str(primary.get('name',''))!=str(alternate.get('name','')),zone+' phase %d rotates to a distinct authored pattern'%phase)
			check(not str(primary.get('phase_hint','')).is_empty(),zone+' phase %d exposes readable mechanic guidance'%phase)

func _test_new_footprints() -> void:
	var origin:=Vector2(700,390)
	var target:=Vector2(410,390)
	var cone:=FIELD.footprint('cone',origin,[target],{'radius':300.0,'half_angle':0.55})
	check(FIELD.contains(cone,Vector2(500,390)),'cone contains a point in front of the boss')
	check(not FIELD.contains(cone,Vector2(700,285)),'cone leaves a lateral safe side')
	check(not FIELD.contains(cone,FIELD.escape_position(cone,Vector2(500,390))),'cone escape helper finds a legal safe position')
	var cross:=FIELD.footprint('cross',origin,[target],{'width':80.0})
	check(FIELD.contains(cross,target),'cross contains its target center')
	check(not FIELD.contains(cross,FIELD.escape_position(cross,target)),'cross exposes a reachable diagonal safe position')
	var lanes:=FIELD.footprint('double_lane',origin,[target],{'width':72.0,'gap':105.0})
	check(FIELD.contains(lanes,Vector2(target.x-105.0,target.y)),'double lane marks the first ore channel')
	check(not FIELD.contains(lanes,target),'double lane preserves a center safe channel')

func _test_target_personality() -> void:
	var game=preload('res://scenes/PortraitMain.tscn').instantiate()
	root.add_child(game)
	for i in 5: await process_frame
	game.selected_faction='aurelia';game.deployed_heroes=game._hero_roster_for_faction().slice(0,4);game._setup_hero_skills()
	var ids: Array[String]=[]
	for hero in game.deployed_heroes:ids.append(str(hero['id']))
	for i in ids.size():
		game.hero_battle_state[ids[i]]['hp']=1000-i*180
		game.hero_battle_state[ids[i]]['max_hp']=1000
		game.hero_battle_state[ids[i]]['row']='front' if i<2 else 'rear'
		game.hero_battle_state[ids[i]]['role_group']='탱커' if i==0 else '딜러'
	game.raid_encounter_zone='moonrest_forest';game.raid_phase=1
	check(game._select_raid_hero_target('lowest_hp')==ids[-1],'forest personality can pressure the lowest-health hero')
	game.hero_battle_state[ids[0]]['taunt']=1.0
	check(game._select_raid_hero_target('lowest_hp')==ids[0],'taunt still overrides regional boss targeting personality')
	game.hero_battle_state[ids[0]]['taunt']=0.0
	check(game._select_raid_hero_target('rear') in ids.slice(2,4),'mine rear cycle selects a back-line hero')
	game.raid_boss_turns=2
	check(game._select_raid_hero_target('row_cycle') in ids.slice(2,4),'even mine cycle pressures rear or middle heroes')
	game.raid_boss_turns=3
	check(game._select_raid_hero_target('row_cycle') in ids.slice(0,2),'odd mine cycle returns pressure to the front')
	game.free()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout

func _test_role_formation() -> void:
	var game=preload('res://scenes/PortraitMain.tscn').instantiate()
	root.add_child(game)
	for i in 5: await process_frame
	game.selected_faction='aurelia';game.deployed_heroes=game._hero_roster_for_faction().slice(0,4);game._setup_hero_skills()
	game.raid_boss_position=Vector2(690,390)
	var ids: Array[String]=[]
	for hero in game.deployed_heroes:ids.append(str(hero['id']))
	for i in ids.size():game.raid_positions[ids[i]]=FIELD.hero_entry(i)
	game.hero_battle_state[ids[0]]['role_group']='탱커';game.hero_battle_state[ids[0]]['ai_style']='protector';game.hero_battle_state[ids[0]]['range']=1
	game.hero_battle_state[ids[1]]['role_group']='서포터';game.hero_battle_state[ids[1]]['ai_style']='support';game.hero_battle_state[ids[1]]['range']=3
	game.hero_battle_state[ids[2]]['role_group']='컨트롤러';game.hero_battle_state[ids[2]]['ai_style']='controller';game.hero_battle_state[ids[2]]['range']=3
	game.hero_battle_state[ids[3]]['role_group']='딜러';game.hero_battle_state[ids[3]]['ai_style']='aggressive';game.hero_battle_state[ids[3]]['range']=1
	var tank: Vector2 = game._raid_role_destination(ids[0],0)
	var support: Vector2 = game._raid_role_destination(ids[1],1)
	var controller: Vector2 = game._raid_role_destination(ids[2],2)
	var melee: Vector2 = game._raid_role_destination(ids[3],3)
	check(tank.distance_to(game.raid_boss_position)<support.distance_to(game.raid_boss_position),'tank holds closer raid frontage than support')
	check(absf(controller.y-game.raid_boss_position.y)>absf(support.y-game.raid_boss_position.y)-5.0,'controller receives a lateral casting lane')
	check(melee.distance_to(game.raid_boss_position)<150.0,'aggressive melee commits to close flanking distance')
	# Follow-up waves use the same live danger shape for movement, fixing the old
	# case where the second earthquake had a warning but no automatic reposition.
	game.raid_running=true;game.raid_encounter_zone='gray_meadow';game.raid_second_wave_remaining=.42
	game.raid_second_wave_shape=FIELD.footprint('earthquake',game.raid_boss_position,[],{'inner':90.0,'outer':240.0})
	game.raid_positions[ids[1]]=game.raid_boss_position+Vector2(-160,0)
	var before: Vector2=game.raid_positions[ids[1]]
	game._raid_move_actors(.10)
	check(game.raid_positions[ids[1]].distance_to(before)>1.0,'second-wave warning can reposition an eligible hero before impact')
	game.free()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
