extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func start(main, faction: String, count := 10) -> void:
	main.raid_running = false
	main.selected_faction = faction
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, count)
	main.hero_progress = {}
	main.hero_equipment = {}
	main.hero_equipment_rarity = {}
	main.hero_equipment_names = {}
	main.hero_equipment_sets = {}
	main.hero_skill_tree = {}
	main.hero_breakthrough = {}
	main.pet_progress = {}
	main.raid_clears = {}
	main.current_zone_id = "moonrest_forest"
	main.active_screen = "raid"
	main._start_raid()
	main.combat_timer.stop()
	main.loot_rng.seed = 271826

func quiet(main) -> void:
	main.pet_runtime = {"kind":"none"}
	main.raid_boss_attack_remaining = 1000.0
	for id in main.hero_skill_runtime:
		main.hero_skill_runtime[id]["remaining"] = 1000.0
		main.hero_skill_runtime[id]["attack_remaining"] = 1000.0
		main.hero_battle_state[id]["ultimate"] = 0.0

func _init() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.combat_effects_enabled = false
	main.battle_speed = 2.0
	main.unclaimed_gold = 0
	main.unclaimed_xp = 0
	var observed: Array = []

	# A controller's non-stun ultimate must not be held behind the interrupt window.
	for id in ["lunea", "nyx", "morgas"]:
		start(main, "aurelia" if id == "lunea" else "noxfera")
		quiet(main)
		main.hero_battle_state[id]["ultimate"] = 100.0
		main.hero_skill_runtime[id]["attack_remaining"] = 0.0
		main._advance_raid_encounter(0.05)
		var applied: float = main._weaken_seconds if id == "lunea" else main._vulnerable_seconds
		check(main.hero_battle_state[id]["ultimate"] == 0.0 and applied > 0.0, "%s must use a ready non-stun ultimate without waiting for telegraph" % id)

	# Skill adapters must route actual stun skills to the raid interrupt + immunity system.
	for id in ["kairen", "bron", "ulric"]:
		start(main, "aurelia" if id == "kairen" else "noxfera")
		quiet(main)
		var runtime: Dictionary = main.hero_skill_runtime[id]
		runtime["remaining"] = 0.0
		runtime["attack_remaining"] = 0.0
		main.boss_telegraph_pending = true
		main.boss_telegraph_remaining = 0.8
		var hp_before: int = main.raid_boss_hp
		main._advance_raid_encounter(0.05)
		check(main.raid_interrupt_count == 1 and not main.boss_telegraph_pending and main.raid_boss_hp < hp_before, "%s skill must deal damage and interrupt the actual raid cast" % id)
		main._stun_seconds = 0.0
		main.boss_telegraph_pending = true
		main.boss_telegraph_remaining = 0.8
		runtime["remaining"] = 0.0
		runtime["attack_remaining"] = 0.0
		main._advance_raid_encounter(0.05)
		check(main.raid_interrupt_count == 1 and main.boss_telegraph_pending and runtime["remaining"] == 0.0, "%s AI must preserve control while boss is immune" % id)

	# Lifesteal must use actual remaining boss HP even with execute/vulnerability multipliers.
	for id in ["valeria", "veyra"]:
		start(main, "noxfera")
		quiet(main)
		var state: Dictionary = main.hero_battle_state[id]
		state["hp"] = 100
		state["max_hp"] = 1000
		state["attack"] = 1000
		main.hero_skill_runtime[id]["remaining"] = 0.0
		main.raid_boss_hp = 17
		main._vulnerable_seconds = 2.0
		var raw: int = main._cast_hero_skill(id)
		var actual: int = main._apply_raid_damage(raw)
		var healed: int = int(state["hp"]) - 100
		check(raw > 17 and actual == 17 and healed >= 1 and healed <= 4, "%s overkill must heal from 17 actual HP, not raw amplified damage; raw=%d healed=%d" % [id, raw, healed])
		main.hero_skill_runtime[id]["remaining"] = 0.0
		check(main._cast_hero_skill(id) == 0 and main.hero_skill_runtime[id]["remaining"] == 0.0, "%s must not spend skill cooldown after boss death" % id)

	# Guard specialization must remain individual vs party-wide in the raid adapter.
	start(main, "aurelia")
	quiet(main)
	main.hero_skill_runtime["leonhardt"]["remaining"] = 0.0
	main._cast_hero_skill("leonhardt")
	check(main.hero_battle_state["leonhardt"]["guard"] > 0.0 and main.hero_battle_state["mira"]["guard"] == 0.0, "Leonhardt raid skill protects himself without global guard leakage")
	main.hero_skill_runtime["orwin"]["remaining"] = 0.0
	main._cast_hero_skill("orwin")
	var protected := 0
	for state in main.hero_battle_state.values():
		if state["guard"] > 0.0:
			protected += 1
	check(protected == 10, "Orwin raid skill protects all ten living heroes")

	# Natural weak-party losses exercise real boss damage and prove defeat grants no rewards.
	for faction in ["aurelia", "noxfera"]:
		start(main, faction, 3)
		var gold_before: int = main.unclaimed_gold
		var xp_before: int = main.unclaimed_xp
		for tick in 321:
			main._on_raid_tick()
			if not main.raid_running:
				break
		observed.append({"faction":faction,"heroes":3,"outcome":main.raid_outcome,"elapsed":snappedf(main.raid_elapsed,0.1),"boss_hp":main.raid_boss_hp,"patterns":main.raid_pattern_count})
		check(main.raid_outcome == "defeat", "%s initial three-hero party should lose to forest boss, not bypass combat" % faction)
		check(main.unclaimed_gold == gold_before and main.unclaimed_xp == xp_before and main.raid_clears.is_empty(), "%s natural defeat must grant no gold XP or clear" % faction)
	print("v27_raid_integration checks=%d failures=%d encounters=%s" % [checks, failures.size(), JSON.stringify(observed)])
	main.free()
	quit(0 if failures.is_empty() else 1)
