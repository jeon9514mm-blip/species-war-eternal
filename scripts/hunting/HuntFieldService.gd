extends RefCounted
## Field orchestration separated from Main; the host owns all mutable state.
const INVASION=preload('res://scripts/hunting/InvasionHuntDirector.gd')

static func spawn_enemy_wave(main: Node, zone: Dictionary) -> void:
	for sprite in main.enemy_wave_sprites:
		if is_instance_valid(sprite): sprite.queue_free()
	for bar in main.enemy_hp_bars:
		if is_instance_valid(bar): bar.queue_free()
	main.enemy_wave.clear(); main.enemy_wave_sprites.clear(); main.enemy_hp_bars.clear()
	main.roaming_hunt.clear_enemies(); main.invasion.reset()
	preload("res://scripts/hunting/HuntProductivity.gd").begin_sample(main)
	preload("res://scripts/hunting/HuntEfficiency.gd").begin(main)
	admit(main, zone)

static func generate_corps(main: Node, zone: Dictionary) -> Array:
	var result: Array = []
	var difficulty = clampi(int(zone.get("difficulty", 1)), 1, 3)
	main.hunt_variety_profile = main.HUNT_VARIETY.encounter_profile(main.hunt_ai.encounter_id, main.idle_stage, difficulty, main.current_zone_id)
	main.hunt_treasure_captured = false
	main.hunt_treasure_expired = false
	main.hunt_event_text = str(main.hunt_variety_profile.get("label", "")) if str(main.hunt_variety_profile.get("type", "standard")) != "standard" else ""
	var count: int = main.invasion.next_size()
	var treasure_index = count - 1 if str(main.hunt_variety_profile.get("type", "standard")) == main.HUNT_VARIETY.EVENT_TREASURE else -1
	var monsters: Array = zone["monsters"]
	var base_index = main.hunt_ai.encounter_id % monsters.size()
	var archetypes: Array = zone.get("wave_pattern", ["brute", "skirmisher", "ranged", "support", "assassin"])
	for index in count:
		var monster_name = str(monsters[(base_index + index) % monsters.size()])
		var species = main.FIELD_ECOLOGY.species_profile(monster_name, str(archetypes[(base_index + index) % archetypes.size()]))
		var archetype = str(species["role"])
		var row: int = 0 if archetype in ["brute", "skirmisher"] else (1 if archetype == "assassin" else 2)
		var hp_scale = 1.55 + float(index % 2) * 0.18 + float(zone["difficulty"]) * 0.08
		if archetype == "brute":
			hp_scale *= 1.22
		elif archetype == "support":
			hp_scale *= 0.82
		var max_hp = maxi(40, int(float(zone["power"]) * hp_scale))
		# More inhabitants must not turn their array position into a damage tier.
		var attack = maxi(4, int(float(zone["power"]) / 12.0 * (0.88 + mini(index, 4) * 0.04)))
		var scheduled_elite = main.idle_stage >= 3 and main.idle_stage % 3 == 0 and index == 0
		var event_elite = index < int(main.hunt_variety_profile.get("elite_count", 0))
		var elite = scheduled_elite or event_elite
		if elite:
			max_hp = int(max_hp * 1.32)
			attack = int(attack * 1.16)
		if archetype == "ranged":
			attack = int(attack * 1.10)
		elif archetype == "assassin":
			attack = int(attack * (1.22 if main.current_zone_id == "moonrest_forest" else 1.18))
		elif archetype == "brute" and main.current_zone_id == "forgotten_mine":
			max_hp = int(max_hp * 1.18)
		elif archetype == "support" and main.current_zone_id == "forgotten_mine":
			attack = int(attack * 0.82)
		attack = maxi(1, int(round(float(attack) * float(main.hunt_variety_profile.get("enemy_attack_mult", 1.0)))))
		if preload("res://scripts/progression/GrowthEconomyRules.gd").solo_starter(main,zone):
			var starter_role: String=str(main.deployed_heroes[0].get("role_group",""))
			var starter_hp_scale: float=.16 if starter_role in ["탱커","서포터"] else .32
			max_hp=maxi(12,int(round(max_hp*starter_hp_scale)))
			attack=maxi(1,int(round(attack*.4)))
		var prepared: Dictionary = main.FIELD_ECOLOGY.prepare_enemy({
			"id": "%d_%d" % [main.hunt_ai.encounter_id, index], "name": monster_name,
			"hp": max_hp, "max_hp": max_hp, "attack": attack, "row": row, "archetype": archetype,
			"elite": elite, "rage_triggered": false, "attack_speed_mult": 1.0,
			"attack_remaining": 0.55 + index * 0.18
		}, main.idle_stage, int(zone.get("unlock_stage", 1)), difficulty)
		if elite:
			main.HUNT_VARIETY.apply_elite_affix(prepared, main.HUNT_VARIETY.elite_affix(main.hunt_ai.encounter_id, index, main.current_zone_id))
		if index == treasure_index:
			prepared["treasure"] = true
			prepared["treasure_remaining"] = float(main.hunt_variety_profile.get("treasure_seconds", 12.0))
			prepared["treasure_expired"] = false
			prepared["treasure_captured"] = false
			prepared["max_hp"] = maxi(1, int(round(float(prepared["max_hp"]) * 0.82)))
			prepared["hp"] = prepared["max_hp"]
			prepared["attack"] = maxi(1, int(round(float(prepared["attack"]) * 0.58)))
			prepared["base_attack"] = prepared["attack"]
		prepared["corps_id"] = main.invasion.serial + 1
		prepared["habitat_pack"] = index / 5
		result.append(prepared)
	return result

static func advance_roaming_hunt(main: Node, delta: float, support_actors: Array[String] = []) -> void:
	var profiling: bool=main.has_meta('hunt_component_times');var stamp:=Time.get_ticks_usec() if profiling else 0
	main.roaming_wave_spawn_cooldown = maxf(0.0, main.roaming_wave_spawn_cooldown - delta)
	main._ensure_roaming_wave()
	if main.enemy_wave.is_empty():
		return
	var immobile: Array = []
	for index in main.enemy_wave.size():
		var enemy: Dictionary=main.enemy_wave[index]
		if main.challenge_session == null:
			enemy["hunt_recovery"]=maxf(0,float(enemy.get("hunt_recovery",0))-delta)
			preload('res://scripts/hunting/HuntAttackDirector.gd').refresh_enemy_intent(main,index)
		immobile.append(float(enemy.get("stun_seconds", 0.0)) > 0.0 or (main.challenge_session == null and (enemy.has("attack_intent") or float(enemy.get("hunt_recovery",0))>0)))
	var enemy_targets: Array[Vector2] = []
	if main.roaming_hunt is INVASION:
		main.roaming_hunt.target_attack_reaches.clear()
		main.roaming_hunt.target_hero_ids.clear()
		main.roaming_hunt.hero_presence.clear();main.roaming_hunt.boss_mask.clear()
		for id in main._alive_hero_ids():main.roaming_hunt.hero_presence.append(main._hero_field_position(id))
	for index in main.enemy_wave.size():
		main.enemy_wave[index]["hunt_target_lock"] = maxf(0.0, float(main.enemy_wave[index].get("hunt_target_lock", 0.0)) - delta)
		var hero_id = main._select_hero_target_for_enemy(index)
		enemy_targets.append(main._hero_field_position(hero_id))
		if main.roaming_hunt is INVASION:
			main.roaming_hunt.target_hero_ids.append(hero_id)
			main.roaming_hunt.boss_mask.append(bool(main.enemy_wave[index].get('is_boss',false)) or bool(main.enemy_wave[index].get('elite',false)))
			main.roaming_hunt.target_attack_reaches.append(main.combat_decisions.spatial_range(int(main.hero_battle_state.get(hero_id,{}).get('range',1))))
	var bodies_before: Array[Dictionary]=[]
	if main.challenge_session==null:
		bodies_before=preload("res://scripts/hunting/HuntBodyCollision.gd").actors(main)
	var result = main.roaming_hunt.advance(delta, main._alive_enemy_mask(), immobile, enemy_targets)
	if profiling:stamp=_profile_time(main,'target_and_roam',stamp)
	preload('res://scripts/hunting/MonsterFlocking.gd').advance(main,delta)
	if profiling:stamp=_profile_time(main,'flocking',stamp)
	for returned_index in result.get("returned_indices", []):
		var enemy: Dictionary = main.enemy_wave[int(returned_index)]
		enemy["hp"] = enemy["max_hp"]
		enemy["attack"] = enemy.get("base_attack", enemy.get("attack", 1))
		enemy["rage_triggered"] = false
		enemy["attack_speed_mult"] = 1.0
		enemy["attack_remaining"] = 0.9
		for status_key in ["stun_seconds", "weaken_seconds", "vulnerable_seconds"]:
			enemy[status_key] = 0.0
		if int(returned_index) < main.enemy_hp_bars.size() and is_instance_valid(main.enemy_hp_bars[int(returned_index)]):
			main.enemy_hp_bars[int(returned_index)].value = 100.0
	main._sync_enemy_wave_summary()
	main.roaming_last_party_velocity = Vector2(result.get("party_velocity", Vector2.ZERO))
	main.expedition_position = main.roaming_hunt.party_position
	main.party_movement.advance(delta, main.deployed_heroes, main.hero_battle_state, main.hero_skill_runtime, main.expedition_position, main.enemy_wave, main.roaming_hunt.enemy_positions, main.roaming_hunt.enemy_returning, main.roaming_hunt.aggro_active, false, main.roaming_hunt.enemy_home_positions)
	if profiling:stamp=_profile_time(main,'party',stamp)
	preload("res://scripts/hunting/HuntBodyCollision.gd").resolve(main,delta,bodies_before)
	if profiling:stamp=_profile_time(main,'collision',stamp)
	var target_index = int(result.get("target_index", -1))
	if target_index >= 0 and target_index < main.enemy_wave.size():
		main.expedition_target = main.roaming_hunt.enemy_position(target_index)
	else:
		main.expedition_target = main.roaming_hunt.patrol_target
	if bool(result.get("encounter_started", false)):
		main.skill_event_text = "⚔ 적 부대 진입 · 각자 목표를 골라 사냥합니다."
		if main.hunt_ai.state != AutoHuntController.State.FIGHTING:
			main._reset_attack_windups(true)
			main.combat_engage_settle_remaining = 1.50
	if main.roaming_hunt.aggro_active:
		if main.hunt_ai.state != AutoHuntController.State.FIGHTING:
			main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
		main._advance_hunt_attacks(delta, support_actors)
	else:
		if main.hunt_ai.state != AutoHuntController.State.MOVING:
			# An abandoned enemy attack must not freeze the actor throughout
			# patrol; only a pending ally heal remains valid after disengaging.
			main._reset_attack_windups(true)
			main.hunt_ai.set_state(AutoHuntController.State.MOVING)
		main.combat_progress = clampf(100.0 * (1.0 - main.roaming_hunt.party_position.distance_to(main.expedition_target) / RoamingHuntDirector.DETECTION_RADIUS), 0.0, 95.0)
	if profiling:_profile_time(main,'attacks',stamp)

static func _profile_time(main,key: String,stamp: int) -> int:
	var now:=Time.get_ticks_usec();var times: Dictionary=main.get_meta('hunt_component_times')
	times[key]=int(times.get(key,0))+now-stamp
	return now

static func advance_auto_hunt_step(main: Node, step: float) -> void:
	if main.challenge_session != null:
		main.CHALLENGE_DRIVER.advance(main, step)
		return
	preload("res://scripts/hunting/HuntEfficiency.gd").advance(main,step)
	main.hunt_ai.advance_time(step)
	main.invasion.advance(step)
	finish_hunt_target(main)
	if main.SAVE_SAFETY.pending(main): return
	main._advance_skill_cooldowns(step)
	main.combat_tick_count += 1
	var support_actors: Array[String] = []
	if main.hunt_ai.state != AutoHuntController.State.RECOVERING and (main.hunt_ai.state in [AutoHuntController.State.MOVING, AutoHuntController.State.LOOTING] or main._should_enter_hunt_recovery()):
		support_actors = main._advance_hunt_support(step)
	var healing_pending = false
	for hero_id in support_actors:
		if float(main.hero_skill_runtime[hero_id].get("windup", -1.0)) >= 0.0:
			healing_pending = true
	if main._should_enter_hunt_recovery() and not healing_pending and main.hunt_ai.state not in [AutoHuntController.State.RECOVERING, AutoHuntController.State.LOOTING]:
		main._begin_hunt_recovery()
	if main.hunt_ai.state == AutoHuntController.State.RECOVERING:
		main.roaming_hunt.mode = RoamingHuntDirector.Mode.RECOVER
		if main.hunt_ai.state_time >= 0.8:
			for hero_id in main.hero_battle_state.keys():
				var state: Dictionary = main.hero_battle_state[hero_id]
				var max_hp = int(state.get("max_hp", 1))
				if int(state.get("hp", 0)) <= 0:
					state["hp"] = maxi(1, int(max_hp * 0.18))
				var healing_time = minf(step, maxf(0.0, main.hunt_ai.state_time - 0.8))
				var healing = float(state.get("recovery_heal_carry", 0.0)) + float(max_hp) * 0.18 * healing_time
				var whole_heal = int(floor(healing))
				state["recovery_heal_carry"] = healing - float(whole_heal)
				state["hp"] = mini(max_hp, int(state["hp"]) + whole_heal)
				state["alive"] = int(state["hp"]) > 0
				if main.hero_hp_bars.has(hero_id) and is_instance_valid(main.hero_hp_bars[hero_id]):
					main.hero_hp_bars[hero_id].value = 100.0 * float(state["hp"]) / maxf(1.0, float(max_hp))
				var slot = int(state.get("slot", -1))
				if slot >= 0 and slot < main.hero_map_sprites.size() and is_instance_valid(main.hero_map_sprites[slot]):
					main.hero_map_sprites[slot].play_idle()
			main._sync_party_hp_from_heroes()
		if main.party_hp >= int(main.party_max_hp * main._hunt_recovery_exit_ratio()):
			# Recovery freezes enemy attack state. Discard old commitments only
			# when the revived party is ready to engage again.
			for enemy in main.enemy_wave:
				enemy.erase('attack_intent')
				enemy['attack_remaining']=maxf(.22,float(enemy.get('attack_remaining',.9)))
			main.hunt_ai.set_state(AutoHuntController.State.MOVING)
			main.roaming_hunt.mode = RoamingHuntDirector.Mode.PATROL
			main.roaming_hunt.aggro_active = false
			main.roaming_hunt.patrol_target = main.roaming_hunt.party_position + Vector2(-0.8 if main.roaming_hunt.party_position.x > RoamingHuntDirector.FIELD_CENTER.x else 0.8, 0.0)

	else:
		main._advance_roaming_hunt(step, support_actors)

	finish_hunt_target(main)
	main._advance_v77_hunt_variety(step)
	main._update_combat_camera(step)
	main._update_map_hero_motion(step)
	main._update_roaming_enemy_motion(step)
	main._hud_elapsed += step
	main._save_elapsed += step
	if main._hud_elapsed >= float(main._presentation_profile()["hud_interval"]):
		main._hud_elapsed = 0.0
		main._update_hunt_hud()
		main._update_map_tiles()
	if main._save_elapsed >= 10.0:
		main._save_elapsed = 0.0
		main._queue_hunt_save()

static func finish_hunt_target(main: Node) -> void:
	if main.challenge_session != null:
		main.CHALLENGE_DRIVER.wave_cleared(main)
		return
	if main.party_hp <= 0: return
	for receipt in main.invasion.take_finished(main.enemy_wave,preload("res://scripts/equipment/EquipmentMailService.gd").available(main)):
		settle_corps(main, receipt.members, receipt.profile)

static func settle_corps(main: Node, fallen: Array, profile: Dictionary) -> void:
	var captured: bool = fallen.any(func(enemy: Dictionary) -> bool: return bool(enemy.get("treasure_captured", false)))
	var expired: bool = fallen.any(func(enemy: Dictionary) -> bool: return bool(enemy.get("treasure_expired", false)))
	var zone: Dictionary = main._current_zone()
	main.combat_progress = 0.0
	main.combat_hunt_cycle += 1
	var defeated_packs: Dictionary = {}
	for enemy in fallen:
		defeated_packs[int(enemy.get("habitat_pack", 0))] = true
	# A 16–20-member corps has four five-member packs, including its partial tail.
	var reward_units = clampi(defeated_packs.size(), 1, 4)
	var difficulty = clampi(int(zone.get("difficulty", 1)), 1, 3)
	var combo_bonus = main._v77_begin_clear_combo(difficulty)
	var event_reward_mult = float(profile.get("reward_mult", 1.0))
	var clear_reward_mult = event_reward_mult * (1.0 + combo_bonus)
	clear_reward_mult *= main.FIELD_ECOLOGY.late_reward_multiplier(main.idle_stage, int(zone.get("unlock_stage", 1)))
	var kill_reward_gold = 0
	var kill_reward_xp = 0
	var stage_reward_gold = 0
	var stage_reward_xp = 0
	var equipment_drops: Array[Dictionary] = []
	var pet_event = ""
	var stage_cleared = false
	for _pack in reward_units:
		main.combat_kills += 1
		main.idle_stage_kills += 1
		if main.combat_kills % 5 == 0:
			main._spawn_open_map_boss()
		var base_pack_gold = int(zone["gold"]) + (main.combat_kills % 3) * int(zone["difficulty"]) * 7
		var base_pack_xp = int(zone["xp"]) + (main.combat_kills % 4) * int(zone["difficulty"]) * 5
		var pack_gold: int = main._guardian_reward(maxi(1, int(round(float(base_pack_gold) * clear_reward_mult))),"online_gold")
		var pack_xp: int = main._guardian_reward(maxi(1, int(round(float(base_pack_xp) * clear_reward_mult))),"online_xp")
		kill_reward_gold += pack_gold
		kill_reward_xp += pack_xp
		main.unclaimed_gold += pack_gold
		main.unclaimed_xp += pack_xp
		main.faction_war_state.add_rations(4 + int(zone["difficulty"]) * 2)
		main._grant_hero_xp(pack_xp)
		var event = main._grant_pet_xp(10 + int(zone["difficulty"]) * 4)
		if not event.is_empty(): pet_event = event
		var equipment_drop: Dictionary = main._roll_equipment_drop(zone)
		if not equipment_drop.is_empty():
			equipment_drops.append({'item':equipment_drop,'handling':main.last_drop_text})
		if main.idle_stage_kills >= main.idle_stage_target and main.idle_stage < 10000:
			main.idle_stage_kills = 0
			var chest: Dictionary=preload("res://scripts/progression/GrowthEconomyRules.gd").stage_chest(main.idle_stage)
			var chest_gold = main._guardian_reward(int(chest.gold),"online_gold")
			var chest_xp = main._guardian_reward(int(chest.xp),"online_xp")
			stage_reward_gold += chest_gold
			stage_reward_xp += chest_xp
			main.idle_chest_gold += chest_gold
			main.idle_chest_xp += chest_xp
			main.faction_war_state.add_rations(int(chest.rations))
			main._grant_hero_xp(chest_xp)
			main.idle_stage += 1
			stage_cleared = true
		elif main.idle_stage >= 10000:
			main.idle_stage = 10000
			main.idle_stage_kills = mini(main.idle_stage_kills, maxi(0, main.idle_stage_target - 1))
	# Field event rewards belong to the one-shot encounter settlement, not boss appearance.
	var variety_bonus_gold = 0
	var variety_bonus_xp = 0
	var bonus_drop: Dictionary = {}
	if captured:
		variety_bonus_gold = main._guardian_reward(int(zone["gold"]) * (2 + difficulty), "online_gold")
		variety_bonus_xp = main._guardian_reward(int(zone["xp"]) * 2, "online_xp")
		bonus_drop = main._v77_guaranteed_hunt_drop(zone, "보물 포획 보상")
	elif bool(profile.get("guaranteed_rare", false)):
		bonus_drop = main._v77_guaranteed_hunt_drop(zone, "행운의 흔적 보상")
	if variety_bonus_gold > 0 or variety_bonus_xp > 0:
		kill_reward_gold += variety_bonus_gold
		kill_reward_xp += variety_bonus_xp
		main.unclaimed_gold += variety_bonus_gold
		main.unclaimed_xp += variety_bonus_xp
		main._grant_hero_xp(variety_bonus_xp)
	if not bonus_drop.is_empty():
		equipment_drops.append({"item":bonus_drop,"handling":main.last_drop_text})
	var latest: Label = main.combat_labels.get("latest")
	if latest != null:
		latest.text = "최근 기록\n몬스터 %d무리 격파! · COMBO x%d\n골드 +%d  ·  경험치 +%d" % [reward_units, main.hunt_combo, kill_reward_gold, kill_reward_xp]
		if str(profile.get("type", "standard")) != "standard":
			latest.text += "\n필드 이벤트 · %s" % str(profile.get("label", "특별 조우"))
		if captured:
			latest.text += " · 보물 포획 성공"
		elif expired:
			latest.text += " · 보물 시간 초과"
		if stage_cleared:
			latest.text += "\n사냥 스테이지 클리어! 상자 획득"
		if not main.hero_level_event.is_empty():
			latest.text += "\n" + main.hero_level_event
		if not main.last_drop_text.is_empty():
			latest.text += "\n" + main.last_drop_text
		if not pet_event.is_empty():
			latest.text += "\n" + pet_event
		main._spawn_floating_combat_text("무리 격파", Color("#ffcf70"), Vector2(535, 255))
	if main.combat_effects_enabled:
		var loot_origin = main.combat_field_rect.position + main.combat_field_rect.size * Vector2(0.55, 0.46)
		main.combat_fx.loot_burst(loot_origin, kill_reward_gold + stage_reward_gold, kill_reward_xp + stage_reward_xp, equipment_drops.size(), stage_cleared)
	if stage_cleared:
		main._show_battle_result_popup("스테이지 돌파", "사냥 스테이지 %d-1 돌파" % (main.idle_stage - 1), "골드 +%d · 경험치 +%d\n%s" % [kill_reward_gold, kill_reward_xp, pet_event], main.GOLD)
	preload("res://scripts/hunting/HuntEfficiency.gd").reward(main,kill_reward_gold+stage_reward_gold)
	main.party_power = main._calculate_party_power()
	main._update_stage_label()
	main._update_map_tiles()
	main._update_reward_labels()
	main._goal_record("hunt_packs", reward_units)
	preload("res://scripts/hunting/HuntProductivity.gd").record(main, reward_units)
	main._on_hunt_reward(kill_reward_gold, kill_reward_xp, equipment_drops, stage_cleared, stage_reward_gold, stage_reward_xp)
	main._queue_hunt_save()

static func admit(main: Node, zone: Dictionary = {}) -> void:
	if main.challenge_session != null or main.hunt_ai.state == AutoHuntController.State.RECOVERING or main.SAVE_SAFETY.pending(main): return
	if not main.invasion.can_enter(main._enemy_wave_alive_count()): return
	compact(main)
	main.hunt_ai.encounter_id = main.invasion.serial + 1
	var members: Array = generate_corps(main, main._current_zone() if zone.is_empty() else zone)
	var corps_id: int = main.invasion.register(main.hunt_variety_profile)
	var start: int = main.enemy_wave.size()
	main.enemy_wave.append_array(members)
	main.roaming_hunt.invasion_enabled = true
	main.party_movement.independent_hunt = true
	main.party_movement.holding_formation = false
	main.roaming_hunt.append_corps(members, corps_id)
	main._spawn_enemy_wave_sprites(start)
	main._sync_enemy_wave_summary()
	main.hunt_event_text = "%s에서 제%d부대 진입 · %d마리 · 생존 %d/25" % [main.roaming_hunt.entry_side(corps_id).name,corps_id,members.size(),main._enemy_wave_alive_count()]

static func compact(main: Node) -> void:
	# Only retire whole settled corps. Live indices and pending attack targets
	# are remapped together, so reinforcements cannot redirect a queued attack.
	var keep: Array[int] = []; var mapping: Dictionary = {}
	for i in main.enemy_wave.size():
		if main.invasion.groups.has(int(main.enemy_wave[i].get("corps_id", -1))):
			mapping[i] = keep.size(); keep.append(i)
		else:
			if i < main.enemy_wave_sprites.size() and is_instance_valid(main.enemy_wave_sprites[i]): main.enemy_wave_sprites[i].queue_free()
			if i < main.enemy_hp_bars.size() and is_instance_valid(main.enemy_hp_bars[i]): main.enemy_hp_bars[i].queue_free()
	if keep.size() == main.enemy_wave.size(): return
	for key: String in ["enemy_wave", "enemy_wave_sprites", "enemy_hp_bars"]:
		var values: Array = main.get(key); var copy: Array = values.duplicate(); values.clear()
		for i in keep:
			if i < copy.size(): values.append(copy[i])
	for key: String in ["enemy_positions","enemy_pack_ids","enemy_wander_targets","enemy_archetypes","enemy_home_positions","enemy_sight_ranges","enemy_leash_ranges","enemy_returning","enemy_alerted"]:
		var values: Array = main.roaming_hunt.get(key); var copy: Array = values.duplicate(); values.clear()
		for i in keep: values.append(copy[i])
	if main.roaming_hunt.has_method('remap_temporary_states'):main.roaming_hunt.remap_temporary_states(mapping)
	main.roaming_hunt.current_target = int(mapping.get(main.roaming_hunt.current_target,-1))
	main.party_movement.formation_threat=int(mapping.get(main.party_movement.formation_threat,-1))
	for id in main.hero_skill_runtime:
		var runtime: Dictionary = main.hero_skill_runtime[id]
		runtime["target_index"] = int(mapping.get(int(runtime.get("target_index",-1)),-1))
	for id in main.party_movement.targets:
		main.party_movement.targets[id] = int(mapping.get(main.party_movement.targets[id],-1))
	for id in main.party_movement.combat_goals:
		var goal: Dictionary = main.party_movement.combat_goals[id]
		goal["target"] = int(mapping.get(int(goal.get("target", -1)), -1))
	for id in main.party_movement.hunt_slots:
		var slot: Dictionary=main.party_movement.hunt_slots[id]
		slot["target"]=int(mapping.get(int(slot.get("target",-1)),-1))
	for id in main.party_movement.blocked_targets:
		var memory: Dictionary = main.party_movement.blocked_targets[id]
		memory["target"] = int(mapping.get(int(memory.get("target", -1)), -1))
	main.field_navigation.clear_routes()
	main.monster_sprite = main.enemy_wave_sprites[0] if not main.enemy_wave_sprites.is_empty() else null
