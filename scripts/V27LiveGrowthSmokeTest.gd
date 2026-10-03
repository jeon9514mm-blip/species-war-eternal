extends SceneTree

# Runs the real action entry points against active combat, including UI-facing
# equip/tree actions. No mocks replace growth, refresh, damage, or status code.
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
	print("V27 LIVE %s: %s" % ["PASS" if condition else "FAIL", label])

func _prepare(main) -> void:
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	for field in ["hero_progress", "hero_equipment", "hero_equipment_rarity", "hero_equipment_names", "hero_equipment_sets", "hero_skill_tree", "hero_ascension", "hero_breakthrough", "pet_progress"]:
		main.set(field, {})
	main.loot_inventory = []
	main.wallet_gold = 100000
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.enemy_wave = [
		{"hp":10000,"max_hp":10000,"attack":100,"row":0,"elite":true,"archetype":"brute"},
		{"hp":10000,"max_hp":10000,"attack":100,"row":0,"elite":true,"archetype":"brute"}
	]
	main.roaming_hunt.configure(Vector2(1.0, 2.0), 2704)
	main.roaming_hunt.spawn_group(main.enemy_wave)
	main.roaming_hunt.enemy_positions = [Vector2(1.4, 2.0), Vector2(6.0, 2.0)] as Array[Vector2]
	main.expedition_position = main.roaming_hunt.party_position
	for hero_id in main.hero_battle_state:
		var state: Dictionary = main.hero_battle_state[hero_id]
		state["hp"] = int(float(state["max_hp"]) * 0.5)
		state["ultimate"] = 73.0
		state["guard"] = 1.7
		state["taunt"] = 0.6
		var runtime: Dictionary = main.hero_skill_runtime[hero_id]
		runtime["remaining"] = 2.1
		runtime["attack_remaining"] = 0.7
		runtime["windup"] = 0.15
		runtime["cast"] = true
		runtime["target_index"] = 0
	main.hero_battle_state["mira"]["hp"] = 0
	main.hero_battle_state["mira"]["alive"] = false
	main.pet_runtime["remaining"] = 0.7
	main._sync_party_hp_from_heroes()

func _snapshot(main) -> Dictionary:
	return {"states":main.hero_battle_state.duplicate(true), "runtime":main.hero_skill_runtime.duplicate(true), "position":main.expedition_position, "pet_remaining":main.pet_runtime.get("remaining", 0.0)}

func _verify_preserved(main, before: Dictionary, action: String) -> bool:
	var intact: bool = main.hero_battle_state.size() == before["states"].size() and main.active_screen == "combat" and main.combat_running
	_check(intact, "%s preserves the active battle and hero states" % action)
	if not intact:
		return false
	var ratios := true
	var resources := true
	var windups := true
	for hero_id in before["states"]:
		var old: Dictionary = before["states"][hero_id]
		var state: Dictionary = main.hero_battle_state[hero_id]
		if int(old["hp"]) > 0:
			var before_ratio := float(old["hp"]) / float(old["max_hp"])
			var after_ratio := float(state["hp"]) / float(state["max_hp"])
			ratios = ratios and absf(before_ratio - after_ratio) <= 1.0 / float(state["max_hp"])
		else:
			ratios = ratios and int(state["hp"]) == 0 and not bool(state["alive"])
		for key in ["ultimate", "guard", "taunt"]:
			resources = resources and state[key] == old[key]
		for key in ["remaining", "attack_remaining", "windup", "cast", "target_index"]:
			windups = windups and main.hero_skill_runtime[hero_id][key] == before["runtime"][hero_id][key]
	_check(ratios, "%s preserves living HP ratios and never revives the fallen hero" % action)
	_check(resources, "%s preserves ultimate gauge and active protection" % action)
	_check(windups and main.expedition_position == before["position"] and main.pet_runtime["remaining"] == before["pet_remaining"], "%s preserves cooldowns, committed actions, position and pet timer" % action)
	return true

func _test_growth_actions(main) -> void:
	_prepare(main)
	var before := _snapshot(main)
	# Exactly 3,600 XP per hero: levels 1 -> 10, with three earned tree points.
	main._grant_hero_xp(10800)
	if _verify_preserved(main, before, "XP level-up"):
		var old: Dictionary = before["states"]["leonhardt"]
		var state: Dictionary = main.hero_battle_state["leonhardt"]
		_check(int(main.hero_progress["leonhardt"]["level"]) == 10 and int(state["attack"]) > int(old["attack"]) and int(state["max_hp"]) > int(old["max_hp"]), "XP updates live attack and max HP immediately")
	before = _snapshot(main)
	var gold_before: int = main.wallet_gold
	main._enhance_equipment(main.deployed_heroes[0], "weapon")
	if _verify_preserved(main, before, "Equipped weapon enhancement"):
		_check(int(main.hero_equipment["leonhardt"]["weapon"]) == 2 and int(main.wallet_gold) == gold_before - 175 and int(main.hero_battle_state["leonhardt"]["attack"]) > int(before["states"]["leonhardt"]["attack"]), "enhancement applies live attack and charges the exact price")
	main.loot_inventory = [{"id":"live_equipment", "slot":"weapon", "level":6, "rarity":"전설", "name":"연계 검증검", "set":"초보자"}]
	before = _snapshot(main)
	main._equip_inventory_item(0, "leonhardt", "live_equipment")
	if _verify_preserved(main, before, "Inventory equip action"):
		_check(int(main.hero_battle_state["leonhardt"]["attack"]) > int(before["states"]["leonhardt"]["attack"]) and int(main.hero_battle_state["leonhardt"]["max_hp"]) > int(before["states"]["leonhardt"]["max_hp"]) and int(main.loot_inventory[0]["level"]) == 2, "equip applies live stats and preserves displaced equipment")
	else:
		# Continue diagnosing subsequent entry points after an independently
		# reported state-loss failure; do not disguise that failure.
		_prepare(main)
		main._grant_hero_xp(10800)
	for branch in ["offense", "survival", "utility"]:
		before = _snapshot(main)
		main._upgrade_skill_tree("leonhardt", branch)
		if _verify_preserved(main, before, "Skill tree " + branch):
			var state: Dictionary = main.hero_battle_state["leonhardt"]
			var old: Dictionary = before["states"]["leonhardt"]
			var changed := int(state["attack"]) > int(old["attack"]) if branch == "offense" else (int(state["max_hp"]) > int(old["max_hp"]) and int(state["defense"]) > int(old["defense"]))
			if branch == "utility":
				changed = float(main.hero_skill_runtime["leonhardt"]["profile"]["cooldown"]) < float(before["runtime"]["leonhardt"]["profile"]["cooldown"])
			_check(changed and int(main.hero_skill_tree["leonhardt"][branch]) == 1, "skill tree %s updates its live attribute" % branch)
		else:
			_prepare(main)
			main._grant_hero_xp(10800)

func _test_local_status_effects(main) -> void:
	_prepare(main)
	main._restore_deployed_heroes(["leonhardt", "lunea"])
	main._setup_hero_skills()
	main.hero_skill_runtime["lunea"]["remaining"] = 0.0
	main._cast_combat_skill("lunea", 0)
	_check(float(main._enemy_status_remaining(0, "weaken")) > 0.0 and float(main._enemy_status_remaining(1, "weaken")) == 0.0, "real Lunea skill applies weakness only inside range")
	var tank: Dictionary = main.hero_battle_state["leonhardt"]
	var hp := int(tank["hp"])
	var reduced := int(main._incoming_damage_to_hero("leonhardt", 100, 0))
	tank["hp"] = hp
	var ordinary := int(main._incoming_damage_to_hero("leonhardt", 100, 1))
	_check(reduced > 0 and reduced < ordinary, "only the weakened enemy deals reduced incoming damage")
	main._apply_enemy_status(0, "vulnerable", 0.5)
	_check(int(main._damage_enemy(0, 100)) == 125 and int(main._damage_enemy(1, 100)) == 100, "vulnerability amplifies actual outgoing damage only on its target")
	main._advance_skill_cooldowns(4.1)
	tank["hp"] = hp
	var expired := int(main._incoming_damage_to_hero("leonhardt", 100, 0))
	_check(expired == ordinary and int(main._damage_enemy(0, 100)) == 100 and float(main._enemy_status_remaining(0, "weaken")) == 0.0, "expired statuses restore ordinary incoming and outgoing damage")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	_test_growth_actions(main)
	_test_local_status_effects(main)
	main.set_process(false)
	main.presentation_runtime.audio.shutdown()
	await create_timer(0.3).timeout
	main.free()
	await process_frame
	print("v27_live_growth_smoke_test checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
