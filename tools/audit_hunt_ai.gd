extends SceneTree
## Read-only audit fixtures. Run with isolated XDG directories; never player saves.
class AuditHost extends "res://scripts/portrait/PortraitMain.gd":
	var watching := false
	var dealt: Dictionary = {}
	var taken: Dictionary = {}
	var healed: Dictionary = {}
	func _damage_enemy(index: int, damage: int, source_index := 0) -> int:
		var enemy: Dictionary = enemy_wave[index] if index >= 0 and index < enemy_wave.size() else {}
		var before := int(enemy.get("hp",0))
		var actual: int = super._damage_enemy(index,damage,source_index)
		if watching and source_index >= 0 and source_index < deployed_heroes.size():
			var id: String = str(deployed_heroes[source_index].id)
			dealt[id] = int(dealt.get(id,0))+maxi(0,before-int(enemy.get("hp",0)))
		return actual
	func _incoming_damage_to_hero(id: String, amount: int, index: int = -1) -> int:
		var state: Dictionary = hero_battle_state.get(id,{})
		var before := int(state.get("hp",0))
		var actual: int = super._incoming_damage_to_hero(id,amount,index)
		if watching: taken[id] = int(taken.get(id,0))+maxi(0,before-int(state.get("hp",0)))
		return actual
	func _heal_hero(id: String, amount: int) -> int:
		var state: Dictionary = hero_battle_state.get(id,{})
		var before := int(state.get("hp",0))
		var actual: int = super._heal_hero(id,amount)
		if watching: healed[id] = int(healed.get(id,0))+maxi(0,int(state.get("hp",0))-before)
		return actual
func _init() -> void: run.call_deferred()
func settle() -> void:
	for i in 5: await process_frame
func ratio(a: float,b: float) -> float: return snappedf(a/maxf(1,b),.001)
func trial(faction: String,count: int,stage: int,level: int,zone: String) -> Dictionary:
	var filter:=OS.get_environment("HUNT_AI_AUDIT_FILTER")
	if not filter.is_empty() and not (faction+"/"+str(count)+"/"+zone) in filter.split(','):return {}
	var main := AuditHost.new()
	main.save_state_path="user://ai-audit-"+str(Time.get_ticks_usec())+".json"
	main._offline_checked=true;root.add_child(main);await settle()
	main.set_process(false);main.set_physics_process(false)
	main.selected_faction=faction;main.current_zone_id=zone;main.idle_stage=154
	main.party_slot_legacy_cap=10;main.combat_effects_enabled=false;main.sound_effects_enabled=false
	main.loot_rng.seed=1004;main.battle_speed=1;main.tutorial_completed=true
	var ids: Array[String]=[]
	for hero in preload("res://scripts/heroes/HeroRosterCatalog.gd").roster(faction):
		if ids.size()<count: ids.append(str(hero.id))
	main._restore_deployed_heroes(ids)
	for id in ids:main.hero_progress[id]={"level":level,"xp":0}
	main.idle_stage=stage;main._build_combat_screen();await settle()
	main.combat_running=true;main.watching=true
	var samples := 0;var close_hero_pairs := 0;var hero_pairs := 0
	var close_enemy_pairs := 0;var enemy_pairs := 0;var recovery_steps := 0
	var idle_steps := 0;var alive_hero_steps := 0;var target_changes := 0
	var target_checks := 0;var desired_targets: Dictionary = {};var previous_enemies: Dictionary = {}
	var live_target_changes := 0;var post_entry_pairs := 0;var post_entry_close_pairs := 0
	var any_close_samples := 0;var invalid_goal_samples := 0;var goal_samples := 0
	var cancelled_dead := 0;var cancelled_range := 0;var cancelled_other := 0
	var ranged_near_threat := 0;var ranged_observations := 0
	var snapshots: Array=[]
	var skill_move_disagree := 0;var skill_choices := 0;var target_count_sum := 0
	var stalled: Dictionary = {};var worst_stall := 0.0
	var created_attacks := 0;var completed_attacks := 0;var cancelled_attacks := 0
	var body_overlaps: Dictionary={'hero_hero':0,'enemy_enemy':0,'hero_enemy':0,'pairs':0};var overlapping_frames:=0;var collision_details: Array=[]
	var start_cycle: int=main.combat_hunt_cycle;var last_cycle: int=start_cycle
	var no_progress := 0.0;var longest_no_progress := 0.0
	var initial_power: int=main._calculate_party_power();var simulation_us := 0
	for n in 1200:
		var before: Dictionary={}
		for id in main.hero_skill_runtime:
			var target: int=main.hero_skill_runtime[id].get("target_index",-1)
			before[id]={"windup":float(main.hero_skill_runtime[id].get("windup",-1)),"target":target,"enemy":main.enemy_wave[target] if target>=0 and target<main.enemy_wave.size() else {}}
		var started := Time.get_ticks_usec()
		main._advance_auto_hunt(.1)
		simulation_us += Time.get_ticks_usec()-started
		if main.hunt_ai.state == AutoHuntController.State.RECOVERING:recovery_steps+=1
		if main.combat_hunt_cycle != last_cycle:no_progress=0;last_cycle=main.combat_hunt_cycle
		else:no_progress+=.1;longest_no_progress=maxf(longest_no_progress,no_progress)
		for id in main.hero_skill_runtime:
			if not before.has(id):continue
			var runtime: Dictionary=main.hero_skill_runtime[id]
			var windup: float=runtime.get("windup",-1)
			if before[id].windup<0 and windup>=0 and int(runtime.get("target_index",-1))>=0:created_attacks+=1
			if before[id].windup>=0 and windup<0 and before[id].target>=0:
				completed_attacks+=1
				if int(runtime.get("target_index",-1))<0:
					cancelled_attacks+=1
					if int(before[id].enemy.get("hp",0))<=0:cancelled_dead+=1
					elif not main._can_attack_enemy(id,int(before[id].target)):cancelled_range+=1
					else:cancelled_other+=1
		if n%5 != 0:continue
		samples+=1
		if n>=100:
			var overlap: Dictionary=preload('res://scripts/hunting/HuntBodyCollision.gd').overlapping(main)
			for key in body_overlaps:body_overlaps[key]+=int(overlap[key])
			if overlap.hero_hero+overlap.enemy_enemy+overlap.hero_enemy>0:
				overlapping_frames+=1
				if collision_details.size()<10:
					var bodies: Array=preload('res://scripts/hunting/HuntBodyCollision.gd').actors(main)
					for a in bodies.size():
						for b in range(a+1,bodies.size()):
							var distance: float=Vector2(bodies[a].position).distance_to(bodies[b].position)
							if distance<preload('res://scripts/hunting/HuntBodyCollision.gd').clearance(bodies[a],bodies[b])-.01:collision_details.append({'seconds':n*.1,'left':bodies[a],'right':bodies[b],'distance':distance})
		var alive: Array=main._alive_hero_ids()
		var chosen: Dictionary={}
		for id in alive:
			alive_hero_steps+=1
			var target: int=main.party_movement.targets.get(id,-1)
			if target>=0:chosen[target]=true
			if desired_targets.has(id) and desired_targets[id]!=target:
				target_changes+=1
				if int(previous_enemies.get(id,{}).get("hp",0))>0:live_target_changes+=1
			previous_enemies[id]=main.enemy_wave[target] if target>=0 and target<main.enemy_wave.size() else {}
			desired_targets[id]=target;target_checks+=1
			var runtime: Dictionary=main.hero_skill_runtime.get(id,{})
			var moving: bool=Vector2(main.party_movement.velocities.get(id,Vector2.ZERO)).length()>.12
			var windup: bool=float(runtime.get("windup",-1))>=0
			var reachable: bool=main._select_enemy_target(id)>=0
			var goal: Dictionary=main.party_movement.combat_goals.get(id,{})
			if not goal.is_empty():
				goal_samples+=1
				if not main.field_navigation.is_walkable(goal.goal):invalid_goal_samples+=1
			if int(main.hero_battle_state[id].range)>=3:
				ranged_observations+=1
				var nearest := INF
				for i in main.enemy_wave.size():
					if int(main.enemy_wave[i].hp)>0:nearest=minf(nearest,main._hero_field_position(id).distance_to(main.roaming_hunt.enemy_position(i)))
				if nearest<.95:ranged_near_threat+=1
			var inactive: bool=not moving and not windup and not reachable and main._enemy_wave_alive_count()>0 and main.hunt_ai.state != AutoHuntController.State.RECOVERING
			if inactive:idle_steps+=1
			stalled[id]=float(stalled.get(id,0))+.5 if inactive else 0.0
			worst_stall=maxf(worst_stall,stalled[id])
			if windup and str(runtime.get("prepared_action","basic"))!="basic" and int(runtime.get("target_index",-1))>=0:
				skill_choices+=1
				if target!=int(runtime.target_index):skill_move_disagree+=1
		target_count_sum+=chosen.size()
		var any_close := false
		for a in alive.size():
			for b in range(a+1,alive.size()):
				hero_pairs+=1
				var close: bool=main._hero_field_position(alive[a]).distance_to(main._hero_field_position(alive[b]))<.9
				if close:close_hero_pairs+=1;any_close=true
				if n>=100:
					post_entry_pairs+=1
					if close:post_entry_close_pairs+=1
		if any_close:any_close_samples+=1
		if n in [100,300,600,900]:
			var points: Dictionary={}
			for id in alive:
				var point: Vector2=main._hero_field_position(id)
				points[id]=[snappedf(point.x,.01),snappedf(point.y,.01)]
			snapshots.append({"seconds":n*.1,"heroes":points})
		var enemies: Array[int]=[]
		for i in main.enemy_wave.size():
			if int(main.enemy_wave[i].hp)>0:enemies.append(i)
		for a in enemies.size():
			for b in range(a+1,enemies.size()):
				enemy_pairs+=1
				if main.roaming_hunt.enemy_position(enemies[a]).distance_to(main.roaming_hunt.enemy_position(enemies[b]))<.9:close_enemy_pairs+=1
		await process_frame
	var roles: Dictionary={}
	for id in main.hero_battle_state:
		roles[id]={"role":str(main.hero_battle_state[id].role_group),"range_world":main.combat_decisions.spatial_range(int(main.hero_battle_state[id].range)),"dealt":main.dealt.get(id,0),"taken":main.taken.get(id,0),"healed":main.healed.get(id,0),"walked":snappedf(main.party_movement.distance_walked.get(id,0),.1)}
	var result: Dictionary={"faction":faction,"zone":zone,"count":main.deployed_heroes.size(),"start_stage":stage,"start_level":level,"start_power":initial_power,"end_stage":main.idle_stage,"seconds":120,"corps_completed":main.combat_hunt_cycle-start_cycle,"recovery_share":ratio(recovery_steps,1200),"hero_pairs_under_0_9_share":ratio(close_hero_pairs,hero_pairs),"enemy_pairs_under_0_9_share":ratio(close_enemy_pairs,enemy_pairs),"inactive_alive_hero_share":ratio(idle_steps,alive_hero_steps),"worst_inactive_seconds":worst_stall,"movement_target_changes":target_changes,"target_observations":target_checks,"avg_distinct_movement_targets":ratio(target_count_sum,samples),"skill_vs_move_target_disagreement_share":ratio(skill_move_disagree,skill_choices),"skill_target_samples":skill_choices,"prepared_hero_attacks_with_enemy_target":created_attacks,"resolved_preparations":completed_attacks,"cancelled_preparations":cancelled_attacks,"longest_seconds_without_corps_clear":snappedf(longest_no_progress,.1),"vm_simulation_ms_per_step":ratio(simulation_us/1000.0,1200),"heroes":roles,"cancelled_dead_target":cancelled_dead,"cancelled_out_of_range_or_invalid":cancelled_range,"cancelled_other":cancelled_other,"live_movement_target_changes":live_target_changes,"post_first_10_seconds_close_hero_pair_share":ratio(post_entry_close_pairs,post_entry_pairs),"samples_with_any_close_hero_pair_share":ratio(any_close_samples,samples),"ranged_with_enemy_inside_0_95_share":ratio(ranged_near_threat,ranged_observations),"non_walkable_stored_goal_samples":invalid_goal_samples,"stored_goal_samples":goal_samples,"position_samples":snapshots}
	result['body_overlap_after_entry']=body_overlaps;result['sampled_frames_with_body_overlap']=overlapping_frames;result['body_overlap_details']=collision_details
	main.presentation_runtime.audio.shutdown();main.free();await create_timer(.35).timeout
	print("HUNT_AI_TRIAL ",JSON.stringify(result));return result
func run() -> void:
	var results: Array=[]
	for faction in ["aurelia","noxfera"]:
		results.append(await trial(faction,1,2,3,"gray_meadow"))
		results.append(await trial(faction,3,5,10,"gray_meadow"))
		results.append(await trial(faction,10,154,60,"gray_meadow"))
	for zone in ["forgotten_mine","moonrest_forest"]:
		results.append(await trial("aurelia",10,154,60,zone))
	results=results.filter(func(row):return not row.is_empty())
	var output:=OS.get_environment("HUNT_AI_AUDIT_OUTPUT")
	if output.is_empty():output="/tmp/hunt-ai-audit.json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"scope":"Eight controlled 120-second rule-based AI trials; fixed loot seed and simulation step; headless Linux, no device FPS or learned-model training","trials":results},"\t")+"\n")
	print("HUNT_AI_AUDIT_COMPLETE ",results.size());quit()
