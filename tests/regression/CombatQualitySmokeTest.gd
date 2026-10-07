extends "res://tests/support/V83UpgradeTestBase.gd"
const FIELD=preload('res://scripts/raid/RaidBattlefield.gd')
const MOVEMENT=preload('res://scripts/hunting/PartyMovementDirector.gd')
const INVASION=preload('res://scripts/hunting/InvasionHuntDirector.gd')
const MOTIONS=preload('res://scripts/portrait/HeroRigMotionCatalog.gd')
func _init() -> void:_run.call_deferred()
func _run() -> void:
	var goals: Dictionary={}
	for i in 10:
		goals[str(i)]=FIELD.hero_entry(i)
		check(FIELD.FLOOR.has_point(goals[str(i)]),'entry within floor')
		for j in i:check(Vector2(goals[str(i)]).distance_to(goals[str(j)])>=50,'initial heroes spaced')
	for i in 10:goals[str(i)]=Vector2(430,390)
	var spread:=FIELD.spread_destinations(goals)
	for id in spread:
		check(FIELD.FLOOR.has_point(spread[id]),'crowded goal stays in floor')
		for other in spread:
			if other!=id:check(Vector2(spread[id]).distance_to(spread[other])>40,'crowded goal separates')
	var danger:=FIELD.footprint('moon_mark',Vector2.ZERO,[Vector2(430,390)],{})
	goals={'a':Vector2(370,390),'b':Vector2(370,390),'c':Vector2(370,390)}
	for goal in FIELD.spread_destinations(goals,danger).values():check(not FIELD.contains(danger,goal),'spread preserves safe destination')
	for serial in range(1,9):
		var movement:=MOVEMENT.new();movement.holding_formation=true
		var direction: Vector2=(INVASION.entry_side(serial).anchor-Vector2(16,10)).normalized()
		var enemy_positions: Array[Vector2]=[Vector2(16,10)+direction*7]
		for step in 80:movement._face_threat(.1,Vector2(16,10),[{'hp':100}],enemy_positions,[false])
		check(movement.formation_facing.dot(direction)>.99,'faces entrance '+str(serial))
		movement.travel_offsets={'tank':Vector2(2,0),'healer':Vector2(-2,0)}
		check((movement.formation_station('tank',Vector2.ZERO)-movement.formation_station('healer',Vector2.ZERO)).dot(direction)>3.9,'tank screens rear '+str(serial))
	var retreat:=INVASION.new();retreat.enemy_positions=[Vector2(16.4,10)];retreat.enemy_archetypes=['ranged']
	retreat.advance(.1,[true],[],[Vector2(16,10)])
	check(retreat.enemy_positions[0].x>16.4,'ranged backs away from contact')
	var frozen:=retreat.enemy_positions[0];retreat.advance(.1,[true],[true],[Vector2(16,10)])
	check(retreat.enemy_positions[0]==frozen,'stun prevents retreat')
	retreat.enemy_positions=[Vector2(25,10)];retreat.target_attack_reaches=[.95]
	for step in 100:retreat.advance(.1,[true],[],[Vector2(16,10)])
	check(retreat.enemy_positions[0].distance_to(Vector2(16,10))<.95,'ranged approaches inside melee target reach instead of stalemate')
	check(INVASION.approach_profile('assassin').speed>INVASION.approach_profile('ranged').speed,'assassin closes faster')
	var signatures: Dictionary={}
	for id in MOTIONS.PROFILES:
		var profile:=MOTIONS.profile(id);signatures[str(profile.signature)]=true
		for action in MOTIONS.ACTIONS:
			var bounded:=true
			for step in 20:
				var pose:=MOTIONS.sample(profile,action,float(step)/20,.9)
				for value in pose.values():bounded=bounded and is_finite(float(value)) and absf(float(value))<1.
			check(bounded,'bounded motion through full track '+id+action)
	check(signatures.size()==30,'thirty authored motion accents')
	var main=await make_main('aurelia',10);main._build_raid_screen();await settle()
	var view=main.content_root.get_node('PortraitRaidView')
	check(view.dodge_button.size.y>=76 and view.dodge_button.size.x>=200,'large dodge target')
	check(view.hero_slots.values()[0].size.x>=128 and view.hero_slots.values()[0].size.y>=108,'large hero selection target')
	var before: String=view.selected_hero_id;var next: String=main.deployed_heroes[1].id
	var touch:=InputEventScreenTouch.new();touch.index=3;touch.pressed=true
	view._on_hero_slot_input(touch,next)
	check(view.selected_hero_id==before,'touch down does not accidentally select')
	var drag:=InputEventScreenDrag.new();drag.index=3;drag.relative=Vector2(40,0);view._on_hero_slot_input(drag,next)
	touch.pressed=false;view._on_hero_slot_input(touch,next)
	check(view.selected_hero_id==before,'swiping leaves selection intact')
	touch.pressed=true;view._on_hero_slot_input(touch,next);touch.pressed=false;view._on_hero_slot_input(touch,next)
	check(view.selected_hero_id==next,'tap release selects hero')
	touch.pressed=true;view._on_hero_slot_input(touch,before)
	view._input(drag);touch.pressed=false;view._input(touch);await settle()
	check(view._slot_pointer==-2,'release consumed by scroll clears touch tracking')
	touch.pressed=true;view._on_hero_slot_input(touch,before);touch.pressed=false;view._on_hero_slot_input(touch,before)
	check(view.selected_hero_id==before,'tap works after consumed scroll release')
	main._start_raid();main.combat_timer.stop()
	main.boss_telegraph_pending=true;main.boss_telegraph_remaining=.7
	main.raid_cast_profile=preload('res://scripts/raid/RaidBossDesign.gd').pattern('gray_meadow',0)
	view.refresh();check(view.cue.text.contains('0.7초'),'warning shows remaining time')
	check(view.stage.has_node('RaidSelectedHeroIndicator'),'selection visible on battlefield')
	var floor_end: Vector2=view.battlefield_3d.project_world(view.battlefield_3d.raid_to_world(FIELD.FLOOR.end))
	print('RAID_FLOOR_EDGE ',floor_end,' stage=',view.stage.size,' dodge=',view.dodge_button.get_rect())
	check(floor_end.y<view.stage.size.y-98,'reachable floor stays above enlarged dodge controls')
	await dispose(main);done('combat_quality')
