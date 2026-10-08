extends RefCounted
class_name HeroKitRuntime

# Side effects share the production HP, status and raid-control paths. A cast
# returns raw raid damage (the caller settles it once), actual field damage.
const CATALOG = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const RULES = preload("res://scripts/heroes/HeroCombatRules.gd")

static func adjusted(main, hero_id: String, slot: String) -> Dictionary:
	var p := CATALOG.skill(hero_id, slot)
	var identity: Dictionary = main.hero_identity_catalog.profile(hero_id)
	var tree: Dictionary = main._get_skill_tree(hero_id)
	if slot != "ultimate":
		p["cooldown"] = maxf(1.2, float(p.get("cooldown", 7.0)) * float(identity.get("skill_cooldown_mult", 1.0)) * (1.0 - float(tree.get("utility", 0)) * 0.03))
	p["value"] = float(p.get("value", 0.0)) * float(identity.get("skill_value_mult", 1.0))
	return p

static func needs_enemy(profile: Dictionary) -> bool:
	return str(profile.get("kind", "damage")) not in ["guard", "heal", "barrier"]

static func _allies(main, hero_id: String, p: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in main._alive_hero_ids():
		if bool(p.get("self_only", false)) and id != hero_id:
			continue
		if bool(p.get("exclude_self", false)) and id == hero_id:
			continue
		if p.has("ally_row") and str(main.hero_battle_state[id].get("row", "")) != str(p["ally_row"]):
			continue
		result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool:
		var x: Dictionary = main.hero_battle_state[a]
		var y: Dictionary = main.hero_battle_state[b]
		var rx := _ally_priority(main, a, p)
		var ry := _ally_priority(main, b, p)
		return int(x["slot"]) < int(y["slot"]) if is_equal_approx(rx, ry) else rx < ry
	)
	result.resize(mini(result.size(), int(p.get("ally_targets", p.get("heal_targets", 1)))))
	return result

static func _ally_priority(main, id: String, profile: Dictionary) -> float:
	var ally: Dictionary = main.hero_battle_state[id]
	var ratio := float(ally.get("hp", 0)) / maxf(1.0, float(ally.get("max_hp", 1)))
	# A healing+shield cast keeps HP triage and resolves both effects on the same
	# recipients. A pure barrier instead skips already protected allies.
	if str(profile.get("kind", "")) != "barrier":
		return ratio
	var desired := maxi(1, int(float(ally.get("max_hp", 1)) * clampf(float(profile.get("shield", .05)), 0.0, .20)))
	var existing := int(ally.get("shield", 0)) if float(ally.get("shield_seconds", 0.0)) > .35 else 0
	var protected_ratio := minf(1.0, float(existing) / float(desired))
	return ratio + protected_ratio * 2.0 - minf(.35, _incoming_threat(main, id) / maxf(1.0, float(ally.get("max_hp", 1))))

static func _incoming_threat(main, id: String) -> float:
	if main.active_screen == "raid":
		return float(main.raid_boss_attack) if main.boss_telegraph_pending else 0.0
	var incoming := 0.0
	for enemy in main.enemy_wave:
		if int(enemy.get("hp", 0)) <= 0 or str(enemy.get("target_id", "")) != id:
			continue
		if float(enemy.get("stun_seconds", 0.0)) <= .35:
			incoming += maxf(0.0, float(enemy.get("attack", 0)))
	return incoming

# Availability stays separate from auto-use so a valid explicit cast keeps its
# mechanics and manual/simulation callers do not inherit tactical hesitation.
static func auto_profile(main, id: String, slot: String) -> Dictionary:
	if slot == "a1" and main.hero_skill_runtime.has(id):
		var runtime: Dictionary = main.hero_skill_runtime[id]
		# Dictionary.get evaluates its default argument even when it has a value.
		# The runtime owns an adjusted profile; avoid copying a discarded catalog.
		if runtime.has("profile"): return runtime["profile"].duplicate(true)
		return CATALOG.skill(id, slot)
	return adjusted(main, id, slot)

static func select_target(main, id: String, slot := "basic") -> int:
	if main.active_screen == "raid":
		return -1
	if slot == "basic" and main.active_screen == "combat" and main.challenge_session == null and main.party_movement.independent_hunt:
		return main._select_enemy_target(id)
	var profile: Dictionary = {} if slot == "basic" else auto_profile(main, id, slot)
	if slot == "basic" and str(CATALOG.skill(id, "passive").get("condition", "")) == "same_target":
		profile["target_retention_bonus"] = .35
	var runtime: Dictionary = main.hero_skill_runtime.get(id, {})
	var ranked: Array[int] = main.combat_decisions.rank_skill_targets(main.hero_battle_state.get(id, {}), main.enemy_wave, profile, main._combat_enemy_distances(id), int(runtime.get("target_index", -1)))
	return preload("res://scripts/hunting/HuntDamageReservations.gd").choose(main,id,ranked[0],profile,ranked) if not ranked.is_empty() else -1

static func priority(main, id: String, slot: String) -> int:
	if not can_use(main, id, slot):
		return 0
	var profile := auto_profile(main, id, slot)
	var kind := str(profile.get("kind", "damage"))
	var state: Dictionary = main.hero_battle_state[id]
	var raid: bool = main.active_screen == "raid"
	var selected := select_target(main, id, slot)
	var affected: Array[int] = []
	if raid:
		affected.append(-1)
	else:
		affected = main._hero_skill_enemy_targets(id, selected, profile)
	var useful_statuses := 0
	var enemies: Array = []
	for index in affected:
		var enemy := _enemy(main, index)
		enemies.append(enemy)
		if kind in ["stun", "weaken", "vulnerable"] and float(enemy.get(kind + "_seconds", 0.0)) <= .35:
			useful_statuses += 1
	var lowest := 1.0
	var threat := 0.0
	# Offensive decisions never read ally triage. Skip its sorting and incoming
	# threat scans while preserving live HP/status reads for support decisions.
	if kind in ["heal", "barrier", "guard"]:
		for ally_id in _allies(main, id, profile):
			var ally: Dictionary = main.hero_battle_state[ally_id]
			lowest = minf(lowest, float(ally["hp"]) / maxf(1.0, float(ally["max_hp"])))
			threat += _incoming_threat(main, ally_id)
	if kind == "heal":
		return 100 if lowest <= .35 else (94 if lowest <= .60 else 82)
	if kind in ["barrier", "guard"] and not raid and enemies.is_empty() and threat <= 0.0:
		var party_in_contact := false
		for ally_id in main._alive_hero_ids():
			if main._select_enemy_target(ally_id) >= 0:
				party_in_contact = true
				break
		if not party_in_contact:
			return 0
	if kind == "barrier":
		return 96 if lowest <= .40 and threat > 0.0 else (80 if threat > 0.0 or lowest < .8 else 60)
	if kind == "guard":
		var context: Dictionary = main._combat_tactic_bundle(id)
		return main.combat_tactics.skill_priority(profile, state, context["party"], context["enemy"], context["boss"])
	if enemies.is_empty():
		return 0
	if kind in ["stun", "weaken", "vulnerable"] and useful_statuses == 0:
		return 0
	var attack := maxf(1.0, float(state.get("attack", 1)))
	var only: Dictionary = enemies[0]
	var only_fragile := enemies.size() == 1 and not bool(only.get("elite", false)) and float(only.get("hp", 0)) <= attack
	if only_fragile and (slot == "ultimate" or kind in ["stun", "weaken", "vulnerable"] or bool(profile.get("aoe", false))):
		# One basic hit finishes this target; retain control/area/ultimate resources.
		return 0
	var score := 60
	if slot == "ultimate": score += 5
	if kind in ["stun", "weaken", "vulnerable"]: score += 15
	if float(profile.get("moving_bonus", 1.0)) > 1.0 and _moving_ready(main, id): score += 12
	if bool(profile.get("aoe", false)):
		score += mini(22, maxi(0, enemies.size() - 1) * 9)
	for enemy in enemies:
		var ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1)))
		if bool(enemy.get("elite", false)): score = maxi(score, 76)
		if ratio <= float(profile.get("execute_threshold", -1.0)): score = maxi(score, 88)
		if _debuffed(enemy) and float(profile.get("status_bonus", 1.0)) > 1.0: score = maxi(score, 82)
	var self_ratio := float(state.get("hp", 0)) / maxf(1.0, float(state.get("max_hp", 1)))
	if float(profile.get("lifesteal", 0.0)) > 0.0 and self_ratio <= .6:
		score = maxi(score, 95 if self_ratio <= .35 else 87)
	return mini(100, score)

static func should_use(main, id: String, slot: String) -> bool:
	return priority(main, id, slot) >= 55

static func preferred_slot(main, id: String) -> String:
	var best := "basic"
	var best_score := 54
	for slot in ["ultimate", "a1", "a2"]:
		if slot=='ultimate' and not main.ultimate_auto:continue
		if slot in ['a1','a2'] and not main.skill_auto:continue
		# The classic kits also retain their role-specific tactical gates.
		if slot == "a1" and not main._should_use_skill(id): continue
		if slot == "ultimate" and not main._should_use_ultimate(id): continue
		var score := priority(main, id, slot)
		if score > best_score:
			best_score = score
			best = slot
	return best

static func shield(main, id: String, ratio: float, duration := 4.0, source_id: String = "") -> void:
	if id.is_empty() or not main.hero_battle_state.has(id):
		return
	var s: Dictionary = main.hero_battle_state[id]
	if int(s.get("hp", 0)) <= 0:
		return
	var amount := int(float(s["max_hp"]) * clampf(ratio, 0.0, 0.20))
	var previous_shield: int = int(s.get("shield", 0))
	s["shield"] = maxi(previous_shield, amount)
	preload("res://scripts/raid/RaidContributionService.gd").add(main, source_id, "shield_given", int(s["shield"]) - previous_shield)
	s["shield_seconds"] = maxf(float(s.get("shield_seconds", 0.0)), minf(duration, 8.0))

static func can_use(main, id: String, slot: String) -> bool:
	if not main.hero_skill_runtime.has(id) or not main.hero_battle_state.has(id):
		return false
	var s: Dictionary = main.hero_battle_state[id]
	if int(s.get("hp", 0)) <= 0:
		return false
	var r: Dictionary = main.hero_skill_runtime[id]
	if slot == "ultimate":
		if not main._ultimate_ready(id):
			return false
	elif float(r.get("remaining" if slot == "a1" else "secondary_remaining", 0.0)) > 0.0:
		return false
	var raid: bool = main.active_screen == "raid"
	var p := CATALOG.skill(id, slot)
	if p.is_empty():
		return false
	# Field healing remains useful between packs. Combat-only effects and all
	# raid actions still stop when their encounter has no living enemy.
	if (raid and main.raid_boss_hp <= 0) or (not raid and str(p.get("kind", "damage")) != "heal" and main._enemy_wave_alive_count() <= 0):
		return false
	if needs_enemy(p):
		if not raid and main._select_enemy_target(id) < 0:
			return false
		if raid and p.get("kind") == "stun" and not main._raid_control_window():
			return false
		return true
	if p.get("kind") == "heal":
		for aid in _allies(main, id, p):
			var ally: Dictionary = main.hero_battle_state[aid]
			if float(ally["hp"]) / float(ally["max_hp"]) < float(p.get("threshold", .88)):
				return true
		return false
	if p.get("kind") == "barrier":
		for aid in _allies(main, id, p):
			var ally: Dictionary = main.hero_battle_state[aid]
			if float(ally.get("shield_seconds", 0.0)) <= .35 or int(ally.get("shield", 0)) < int(float(ally["max_hp"]) * float(p.get("shield", .05)) * .5):
				return true
		return false
	if p.get("kind") == "guard":
		for aid in main._alive_hero_ids():
			if (p.get("guard_scope", "self") == "party" or aid == id) and float(main.hero_battle_state[aid].get("guard", 0.0)) < .5:
				return true
		return false
	return true

static func _enemy(main, index: int) -> Dictionary:
	if main.active_screen == "raid":
		return {"hp":main.raid_boss_hp, "max_hp":main.raid_boss_max_hp, "elite":true, "stun_seconds":main._stun_seconds, "weaken_seconds":main._weaken_seconds, "vulnerable_seconds":main._vulnerable_seconds}
	if index >= 0 and index < main.enemy_wave.size():
		return main.enemy_wave[index].duplicate(true)
	return {}

static func _has_status(e: Dictionary, status: String) -> bool:
	return float(e.get(status + "_seconds", 0.0)) > 0.0

static func _debuffed(e: Dictionary) -> bool:
	return _has_status(e, "stun") or _has_status(e, "weaken") or _has_status(e, "vulnerable")

static func _moving_ready(main, id: String) -> bool:
	var r: Dictionary = main.hero_skill_runtime[id]
	if main.active_screen == "raid":
		return int(r.get("kit_basic_count", 0)) >= int(r.get("kit_last_move_basic", 0)) + 3
	var origin: Vector2 = r.get("kit_last_move_position", main._hero_field_position(id))
	return main._hero_field_position(id).distance_to(origin) >= .6

static func _consume_movement(main, id: String) -> void:
	var r: Dictionary = main.hero_skill_runtime[id]
	r["kit_last_move_basic"] = int(r.get("kit_basic_count", 0))
	r["kit_last_move_position"] = main._hero_field_position(id)

static func _status(main, index: int, kind: String, duration: float, source_id: String = "") -> void:
	if main.active_screen == "raid":
		match kind:
			"stun": main._raid_apply_control(duration, source_id)
			"weaken": main._weaken_seconds = maxf(main._weaken_seconds, duration)
			"vulnerable": main._vulnerable_seconds = maxf(main._vulnerable_seconds, duration)
	else:
		main._apply_enemy_status(index, kind, duration)

static func cast(main, id: String, slot: String, target := -1) -> int:
	if not can_use(main, id, slot):
		return 0
	var p := adjusted(main, id, slot)
	var raid: bool = main.active_screen == "raid"
	if needs_enemy(p) and not raid and not main._can_attack_enemy(id, target):
		return 0
	var s: Dictionary = main.hero_battle_state[id]
	var r: Dictionary = main.hero_skill_runtime[id]
	var kind := str(p.get("kind", "damage"))
	var attack := int(s["attack"])
	var total := 0
	var actual := 0
	var targets: Array[int] = []
	# v31: observational FX metadata only; selected targets and all combat math stay unchanged.
	var visual_targets: Array[int] = []
	var visual_target_hits: Dictionary = {}
	var visual_allies: Array[Dictionary] = []
	if raid:
		targets.append(-1)
	else:
		targets = main._hero_skill_enemy_targets(id, target, p)
	# Resolve recipients once: healing can change HP order before the shield part
	# of the same cast. Both effects must reach the allies chosen at cast time.
	var ally_targets: Array[String] = []
	if kind == "heal" or float(p.get("shield", 0.0)) > 0.0:
		ally_targets = _allies(main, id, p)
	# Commit only after target/usefulness validation. Failed casts spend nothing.
	if slot == "ultimate":
		s["ultimate"] = 0.0
	else:
		r["remaining" if slot == "a1" else "secondary_remaining"] = float(p["cooldown"])
	if p.has("hp_cost"):
		s["hp"] = maxi(1, int(s["hp"]) - int(float(s["hp"]) * float(p["hp_cost"])))
	if kind == "guard":
		var hp_before := int(s["hp"])
		main._perform_hero_guard(id, p)
		for aid in main._alive_hero_ids():
			if p.get("guard_scope", "self") == "party" or aid == id:
				visual_allies.append({"hero_id":aid, "mode":"guard"})
		if int(s["hp"]) > hp_before:
			visual_allies.append({"hero_id":id, "mode":"heal"})
	if kind == "heal":
		for aid in ally_targets:
			if _credited_heal(main, aid, RULES.heal_amount(p, main.hero_battle_state[aid]), id) > 0:
				visual_allies.append({"hero_id":aid, "mode":"heal"})
	if p.has("heal_value"):
		main._perform_hero_healing({"value":p["heal_value"], "heal_targets":p.get("heal_targets",1)}, visual_allies, id)
	if float(p.get("shield", 0.0)) > 0.0:
		for aid in ally_targets:
			shield(main, aid, float(p["shield"]), float(p.get("duration", 4.0)), id)
			visual_allies.append({"hero_id":aid, "mode":"shield"})
	if needs_enemy(p):
		var hits := maxi(1, int(p.get("hits", 1)))
		for hit in hits:
			for ti in targets.size():
				var index := targets[ti]
				if not raid and not main._can_attack_enemy(id, index):
					if bool(p.get("aoe", false)):
						continue
					index = select_target(main, id, slot)
					if index < 0:
						continue
					targets[ti] = index
				if not visual_targets.has(index): visual_targets.append(index)
				visual_target_hits[index] = int(visual_target_hits.get(index, 0)) + 1
				var e := _enemy(main, index)
				if kind in ["stun", "weaken", "vulnerable"]:
					_status(main, index, kind, float(p.get("duration", 2.0)), id)
				if p.has("status"):
					_status(main, index, str(p["status"]), float(p.get("status_duration", 1.5)), id)
				var scale := 1.0 / float(hits)
				if _debuffed(e): scale *= float(p.get("status_bonus", 1.0))
				if float(s.get("guard", 0.0)) > 0.0: scale *= float(p.get("guarded_bonus", 1.0))
				if float(e.get("hp", 0)) / maxf(1.0, float(e.get("max_hp",1))) >= float(p.get("high_hp_threshold", 2.0)):
					scale *= float(p.get("high_hp_bonus", 1.0))
				if float(s["hp"]) / float(s["max_hp"]) <= .5: scale *= float(p.get("low_hp_damage_bonus", 1.0))
				if _moving_ready(main, id): scale *= float(p.get("moving_bonus", 1.0))
				var damage_profile := p.duplicate(true)
				if raid and p.has("raid_value"): damage_profile["value"] = p["raid_value"]
				var raw := RULES.hit_damage(damage_profile, attack, e, scale) if float(p.get("value", 0.0)) > 0.0 else 0
				if raid:
					total += raw
				else:
					main.set_meta('settled_skill_slot',slot)
					total += main._damage_enemy(index, raw, int(s["slot"]))
					main.remove_meta('settled_skill_slot')
		actual = mini(int(main.raid_boss_hp), int(float(total) * (1.25 if main._vulnerable_seconds > 0.0 else 1.0))) if raid else total
	if p.has("lifesteal"):
		if _credited_heal(main, id, RULES.lifesteal_amount(p, s, actual), id) > 0:
			visual_allies.append({"hero_id":id, "mode":"return"})
	if p.has("self_heal") and kind != "guard":
		if _credited_heal(main, id, int(float(s["max_hp"]) * float(p["self_heal"])), id) > 0:
			visual_allies.append({"hero_id":id, "mode":"heal"})
	if p.has("self_guard"):
		s["guard"] = maxf(float(s.get("guard", 0.0)), float(p["self_guard"]))
		visual_allies.append({"hero_id":id, "mode":"guard"})
	if p.has("taunt"): s["taunt"] = maxf(float(s.get("taunt", 0.0)), float(p["taunt"]))
	if p.has("reduce_secondary"): r["secondary_remaining"] = maxf(0.0, float(r.get("secondary_remaining", 0.0)) - float(p["reduce_secondary"]))
	if slot != "ultimate": main._gain_ultimate(id, (15.0 if slot == "a1" else 9.0) + float(p.get("energy", 0.0)))
	if p.has("moving_bonus"): _consume_movement(main, id)
	r["casts_" + slot] = int(r.get("casts_" + slot, 0)) + 1
	main.skill_event_text = "%s · %s" % [main._hero_short_name(id), str(p["skill"])]
	var visual_profile := p.duplicate(true)
	visual_profile["fx_slot"] = slot
	visual_profile["fx_cast_serial"] = int(r["casts_" + slot])
	visual_profile["fx_targets"] = visual_targets
	visual_profile["fx_target_hits"] = visual_target_hits
	visual_profile["fx_allies"] = visual_allies
	main._emit_skill_cast_fx(id, target, bool(p.get("aoe", false)), visual_profile, slot == "ultimate")
	if slot == "ultimate": main._emit_ultimate_cutin(id, str(p["skill"]))
	total += event(main, id, "cast", target)
	main._sync_party_hp_from_heroes()
	return total

static func event(main, id: String, event_name: String, target := -1, snapshot: Dictionary = {}) -> int:
	if not main.hero_battle_state.has(id) or not main.hero_skill_runtime.has(id):
		return 0
	var s: Dictionary = main.hero_battle_state[id]
	if int(s.get("hp", 0)) <= 0:
		return 0
	var r: Dictionary = main.hero_skill_runtime[id]
	if event_name == "basic": r["kit_basic_count"] = int(r.get("kit_basic_count", 0)) + 1
	var p := CATALOG.skill(id, "passive")
	if p.is_empty() or p["event"] != event_name:
		return 0
	var enemy := snapshot if not snapshot.is_empty() else _enemy(main, target)
	var condition := str(p["condition"])
	var injured := 0
	var shielded := false
	for aid in main._alive_hero_ids():
		var ally: Dictionary = main.hero_battle_state[aid]
		if int(ally["hp"]) < int(ally["max_hp"]): injured += 1
		if int(ally.get("shield", 0)) > 0: shielded = true
	var allowed := true
	match condition:
		"guarded": allowed = float(s.get("guard", 0.0)) > 0.0
		"injured_ally": allowed = injured > 0
		"two_injured": allowed = injured >= 2
		"shielded_ally": allowed = shielded
		"self_low": allowed = float(s["hp"]) / float(s["max_hp"]) <= .5
		"target_low": allowed = not enemy.is_empty() and float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1))) <= .35
		"elite": allowed = bool(enemy.get("elite", false))
		"many_enemies": allowed = main.active_screen != "raid" and main._enemy_wave_alive_count() >= 2
		"moved": allowed = _moving_ready(main, id)
		"controlled", "weakened", "vulnerable", "debuffed":
			allowed = false
			var enemies: Array = [_enemy(main, -1)] if main.active_screen == "raid" else main.enemy_wave
			for ei in enemies.size():
				var e: Dictionary = enemies[ei]
				if int(e.get("hp", 0)) <= 0 or (main.active_screen == "combat" and main.roaming_hunt.is_returning(ei)): continue
				allowed = allowed or (_debuffed(e) if condition == "debuffed" else _has_status(e, {"controlled":"stun", "weakened":"weaken", "vulnerable":"vulnerable"}[condition]))
		"same_target":
			var serial := "%d:%d" % [int(main.hunt_ai.encounter_id) if main.active_screen != "raid" else int(main.raid_encounter_serial), target]
			if str(r.get("passive_target", "")) != serial: r["passive_count"] = 0
			r["passive_target"] = serial
	if not allowed or float(r.get("passive_remaining", 0.0)) > 0.0:
		return 0
	r["passive_count"] = int(r.get("passive_count", 0)) + 1
	if int(r["passive_count"]) < int(p.get("every", 1)):
		return 0
	r["passive_count"] = 0
	r["passive_remaining"] = float(p.get("cooldown", 0.0))
	r["passive_procs"] = int(r.get("passive_procs", 0)) + 1
	if condition == "moved": _consume_movement(main, id)
	var value := float(p["value"])
	var lowest: String = main._lowest_hp_hero_id()
	# One notification per confirmed proc, never on cooldown ticks or failed conditions.
	main._emit_passive_proc_fx(id, target, p, lowest)
	match str(p["action"]):
		"energy": main._gain_ultimate(id, value)
		"cooldown": r["secondary_remaining"] = maxf(0.0, float(r.get("secondary_remaining", 0.0)) - value)
		"heal": _credited_heal(main, id, int(float(s["max_hp"]) * value), id)
		"ally_heal":
			if not lowest.is_empty(): _credited_heal(main, lowest, int(float(main.hero_battle_state[lowest]["max_hp"]) * value), id)
		"shield": shield(main, id, value, 4.0, id)
		"ally_shield": shield(main, lowest, value, 4.0, id)
		"guard": s["guard"] = maxf(float(s.get("guard", 0.0)), value)
		"ally_guard":
			if not lowest.is_empty(): main.hero_battle_state[lowest]["guard"] = maxf(float(main.hero_battle_state[lowest].get("guard", 0.0)), value)
		"damage":
			var damage := int(float(s["attack"]) * value)
			if main.active_screen == "raid": return damage
			if main._can_attack_enemy(id, target): return main._damage_enemy(target, damage, int(s["slot"]))
	return 0

static func tick(main, delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	for id in main.hero_skill_runtime:
		var r: Dictionary = main.hero_skill_runtime[id]
		for key in ["secondary_remaining", "passive_remaining"]:
			r[key] = maxf(0.0, float(r.get(key, 0.0)) - delta)
	for s in main.hero_battle_state.values():
		s["shield_seconds"] = maxf(0.0, float(s.get("shield_seconds", 0.0)) - delta)
		if float(s["shield_seconds"]) <= 0.0 or int(s.get("hp", 0)) <= 0: s["shield"] = 0

static func _credited_heal(main, target: String, amount: int, source: String) -> int:
	var actual: int = main._heal_hero(target, amount)
	preload("res://scripts/raid/RaidContributionService.gd").add(main, source, "healing_given", actual)
	return actual
