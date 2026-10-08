extends 'res://tests/support/V83UpgradeTestBase.gd'
const BEFORE=preload('res://tools/diagnostics/ultra-vfx-2026-10-08/reference/HuntPositionPlanner.gd')
const AFTER=preload('res://scripts/hunting/HuntPositionPlanner.gd')
const OLD_PARTY=preload('res://tools/diagnostics/ultra-vfx-2026-10-08/reference/PartyMovementDirector.gd')
var report: Dictionary={'decision_checks':0,'trajectory_steps':0,'reference_us':0,'optimized_us':0,'exact_state_match':true,'failures':[]}
func _init() -> void:run.call_deferred()
func decisions() -> void:
	var random:=RandomNumberGenerator.new();random.seed=2026100815
	var roster: Array=ROSTER.roster('aurelia').slice(0,10)
	for fixture in 40:
		var director:=PartyMovementDirector.new();director.independent_hunt=true
		var states: Dictionary={};var runtimes: Dictionary={};var points: Array[Vector2]=[];var enemies: Array=[]
		for hero in roster:
			states[hero.id]={'hp':100,'range':random.randi_range(1,3),'role_group':hero.role_group,'row':'middle'}
			runtimes[hero.id]={'windup':.2 if random.randf()<.3 else -1.0}
		director.configure(roster,states,Vector2(16,10))
		var reserved: Dictionary={}
		for hero in roster:
			director.positions[hero.id]=Vector2(random.randf_range(12,20),random.randf_range(7,13))
			reserved[hero.id]=director.positions[hero.id]+Vector2(random.randf_range(-1,1),random.randf_range(-1,1))
		for enemy_index in 31:
			points.append(Vector2(random.randf_range(12,20),random.randf_range(7,13)))
			enemies.append({'hp':100,'attack_intent':roster[enemy_index%10].id if enemy_index%3==0 else ''})
		for change in 4:
			# Eligibility changes before every new choice. A stale cache would retain
			# the dead/revived ally or enemy and select a different destination.
			for hero_index in roster.size():
				var id: String=roster[hero_index].id
				states[id].hp=0 if (hero_index+change)%4==0 else 100
				runtimes[id].windup=.2 if (hero_index+change)%3==0 else -1.0
				reserved[id]=director.positions[id]+Vector2(float(change)*.12,-float(change)*.08)
			for enemy_index in enemies.size():enemies[enemy_index].hp=0 if (enemy_index+change)%5==0 else 100
			for hero in roster:
				var id: String=hero.id;var target:=posmod(fixture+change,points.size())
				var start: Vector2=director.positions[id];var desired:=points[target]+Vector2(random.randf_range(-1,1),random.randf_range(-1,1))
				var old_slots: Dictionary=director.hunt_slots.duplicate(true);var old_goals: Dictionary=director.combat_goals.duplicate(true)
				var stamp:=Time.get_ticks_usec();var expected: Vector2=BEFORE.choose(director,id,start,target,desired,states[id],states,director.positions,reserved,enemies,points,runtimes)
				report.reference_us+=Time.get_ticks_usec()-stamp
				var expected_slots: Dictionary=director.hunt_slots.duplicate(true);var expected_goals: Dictionary=director.combat_goals.duplicate(true)
				director.hunt_slots=old_slots;director.combat_goals=old_goals
				stamp=Time.get_ticks_usec();var actual: Vector2=AFTER.choose(director,id,start,target,desired,states[id],states,director.positions,reserved,enemies,points,runtimes)
				report.optimized_us+=Time.get_ticks_usec()-stamp
				check(actual==expected and director.hunt_slots==expected_slots and director.combat_goals==expected_goals,'exact cached decision '+str(fixture)+':'+str(change)+':'+id)
				report.decision_checks+=1
func snapshot(main) -> Dictionary:
	return {'hero_positions':main.party_movement.positions.duplicate(true),'hero_velocities':main.party_movement.velocities.duplicate(true),'distance_walked':main.party_movement.distance_walked.duplicate(true),'targets':main.party_movement.targets.duplicate(true),'hunt_slots':main.party_movement.hunt_slots.duplicate(true),'goals':main.party_movement.combat_goals.duplicate(true),'enemy_positions':main.roaming_hunt.enemy_positions.duplicate(),'hero_states':main.hero_battle_state.duplicate(true),'hero_runtime':main.hero_skill_runtime.duplicate(true),'enemy_wave':main.enemy_wave.duplicate(true),'wallet':[main.wallet_gold,main.wallet_xp,main.wallet_gems,main.unclaimed_gold,main.unclaimed_xp],'stage':[main.idle_stage,main.idle_stage_kills,main.combat_hunt_cycle],'loot_rng':main.loot_rng.state,'roam_rng':main.roaming_hunt.rng.state,'fear_rng':main.roaming_hunt.fear_rng.state}
func prepared_main(faction: String,reference: bool):
	var main=await make_main(faction,10)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1120,630)
	if reference:main.party_movement=OLD_PARTY.new()
	main.idle_stage=154;main.tutorial_completed=true;main.loot_rng.seed=20261008
	main.sound_effects_enabled=false;main.combat_effects_enabled=true;main.combat_fx.enabled=true
	main._build_combat_screen();await settle();main.combat_running=true
	main.presentation_runtime.contact_time.enabled=false
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	main.combat_labels.terrain.set_process(false)
	return main
func trajectories() -> void:
	for faction in ['aurelia','noxfera']:
		var before=await prepared_main(faction,true);var after=await prepared_main(faction,false)
		for step in 240:
			before._advance_auto_hunt(.05);before.combat_labels.terrain._process(0)
			after._advance_auto_hunt(.05);after.combat_labels.terrain._process(0)
			var original:=snapshot(before);var optimized:=snapshot(after);var identical:=original==optimized
			check(identical,'exact natural trajectory/damage/RNG '+faction+':'+str(step));report.trajectory_steps+=1
			if not identical:
				var differing: Array[String]=[]
				for key in original:
					if original[key]!=optimized[key]:differing.append(key)
				report.exact_state_match=false;report.failures.append({'faction':faction,'step':step,'different_fields':differing});break
		before.combat_running=false;after.combat_running=false;await dispose(before);await dispose(after)
func run() -> void:
	decisions();await trajectories()
	report.reference_source_sha256=FileAccess.get_file_as_string('res://tools/diagnostics/ultra-vfx-2026-10-08/reference/HuntPositionPlanner.gd').sha256_text()
	report.checks=checks;report.passed=failures.is_empty()
	var file:=FileAccess.open('res://checks/ultra-vfx-2026-10-08/planner-equivalence.json',FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,'  ')+'\n');file.close()
	print('ULTRA_PLANNER_EQUIVALENCE '+JSON.stringify(report));done('ULTRA_PLANNER_EQUIVALENCE_OK')
