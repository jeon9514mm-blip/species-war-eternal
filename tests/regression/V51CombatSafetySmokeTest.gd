extends SceneTree

const KITS = preload("res://scripts/heroes/HeroKitRuntime.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _prepare(main, ids: Array, faction: String, raid := false) -> void:
	main.party_slot_legacy_cap = 10
	main.selected_faction = faction
	main._restore_deployed_heroes(ids)
	main._setup_hero_skills()
	main.active_screen = "raid" if raid else "combat"
	main.combat_running = false
	main.raid_running = raid
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.raid_boss_hp = 10000
	main.raid_boss_max_hp = 10000
	main.raid_boss_attack = 100
	main.raid_damage_dealt = 0
	main._guard_seconds = 0.0
	main._weaken_seconds = 0.0
	main._vulnerable_seconds = 0.0
	main._stun_seconds = 0.0
	main.enemy_wave = [{"hp":10000, "max_hp":10000, "attack":100, "row":0, "elite":false, "archetype":"brute"}]
	for id in main.hero_battle_state:
		var state: Dictionary = main.hero_battle_state[id]
		state["hp"] = 1000
		state["max_hp"] = 1000
		state["attack"] = 100
		state["guard"] = 0.0
		state["shield"] = 0
		state["shield_seconds"] = 0.0
		var runtime: Dictionary = main.hero_skill_runtime[id]
		runtime["remaining"] = 0.0
		runtime["secondary_remaining"] = 0.0
		runtime["passive_remaining"] = 0.0
	main._sync_party_hp_from_heroes()

func _test_combined_support(main) -> void:
	for raid in [false, true]:
		for fixture in [["elisia", "leonhardt", "mira", "aurelia"], ["selene", "valeria", "bron", "noxfera"]]:
			var ids: Array = fixture.slice(0, 3)
			var caster: String = ids[0]
			_prepare(main, ids, fixture[3], raid)
			for index in ids.size():
				main.hero_battle_state[ids[index]]["hp"] = 200 + index * 10
			# Do not conflate the separate post-cast passive with the two skill recipients.
			main.hero_skill_runtime[caster]["passive_remaining"] = 10.0
			_check(KITS.can_use(main, caster, "a2"), "%s support fixture is usable" % caster)
			KITS.cast(main, caster, "a2")
			var context := "%s/%s" % [caster, "raid" if raid else "field"]
			for index in 2:
				var state: Dictionary = main.hero_battle_state[ids[index]]
				_check(int(state["hp"]) > 200 + index * 10, context + " heals originally selected ally " + ids[index])
				_check(int(state.get("shield", 0)) > 0, context + " shields the same selected ally " + ids[index])
			var third: Dictionary = main.hero_battle_state[ids[2]]
			_check(int(third["hp"]) == 220 and int(third.get("shield", 0)) == 0, context + " does not retarget after healing changes HP order")
			var before := JSON.stringify(main.hero_battle_state)
			KITS.cast(main, caster, "a2")
			_check(before == JSON.stringify(main.hero_battle_state), context + " immediate recast spends no extra heal or shield")
			_check(int(main.hero_skill_runtime[caster].get("casts_a2", 0)) == 1, context + " commits exactly once")

func _test_boss_counter_kill(main) -> void:
	for kind in ["curse", "aoe", "front_blast"]:
		_prepare(main, ["bron", "valeria"], "noxfera", true)
		main.raid_boss_hp = 1
		main.hero_battle_state["bron"]["guard"] = 1.0
		main._apply_boss_pattern({"kind":kind, "multiplier":1.4})
		_check(int(main.hero_skill_runtime["bron"].get("passive_procs", 0)) == 1, kind + " fixture triggers lethal Bron counter")
		_check(main.raid_boss_hp == 0, kind + " counter-killed boss remains dead")
		_check(main.hero_battle_state["valeria"]["hp"] == 1000, kind + " dead boss cannot continue to the next ally")
		_check(main.raid_damage_dealt == 1, kind + " counter damage settles once without overkill credit")
	# Exercise the production tick too: victory must settle on the counter-hit
	# tick, with the usual reward idempotency even if another timer fires.
	_prepare(main, ["bron", "valeria"], "noxfera", true)
	main.current_zone_id = "moonrest_forest"
	main._reset_raid_encounter()
	main.raid_boss_hp = 1
	main.hero_battle_state["bron"]["guard"] = 1.0
	main.pet_runtime = {}
	for runtime in main.hero_skill_runtime.values():
		runtime["attack_remaining"] = 100.0
	main.boss_telegraph_pending = true
	main.boss_telegraph_remaining = 0.01
	var gold_before: int = main.unclaimed_gold
	main._advance_raid_encounter(0.05)
	_check(main.raid_outcome == "victory" and not main.raid_running and main.raid_reward_settled, "counter kill settles victory during the same production tick")
	_check(main.unclaimed_gold > gold_before, "counter victory awards the normal raid reward")
	var gold_after: int = main.unclaimed_gold
	var receipt: Dictionary = main.raid_reward_receipt.duplicate(true)
	main._advance_raid_encounter(0.05)
	main._finish_raid("victory")
	_check(main.unclaimed_gold == gold_after and main.raid_reward_receipt == receipt, "counter victory cannot award duplicate rewards")

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.set_process(false)
	_test_combined_support(main)
	_test_boss_counter_kill(main)
	main.free()
	print("V51CombatSafetySmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
