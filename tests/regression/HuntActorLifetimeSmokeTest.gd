extends "res://tests/support/V83UpgradeTestBase.gd"

func _init() -> void: run.call_deferred()

func assert_owned_bars(main: Node, expected: Array, label: String) -> void:
	var keys: Array = main.hero_hp_bars.keys(); keys.sort()
	var sorted_ids := expected.duplicate(); sorted_ids.sort()
	check(keys == sorted_ids, label + " health references contain only deployed heroes")
	var actors: Node = main.combat_labels.actor_layer
	var owned_count := 0; var orphan_count := 0
	for bar: ProgressBar in actors.find_children("*", "ProgressBar", true, false):
		if bar in main.enemy_hp_bars: continue
		if bar in main.hero_hp_bars.values(): owned_count += 1
		else: orphan_count += 1
	check(owned_count == expected.size() and orphan_count == 0, label + " field contains exactly one owned health bar per hero")

func run() -> void:
	for faction in ["aurelia", "noxfera"]:
		var main = await make_main(faction, 10)
		main._open_home(); await settle(); main.combat_running = false
		var hunt_id: int = main.content_root.get_instance_id()
		var original: Array = main._deployed_hero_ids().duplicate()
		var injured: String = str(original[0])
		main.hero_battle_state[injured].hp = int(main.hero_battle_state[injured].max_hp) / 2
		var health_before: int = main.hero_battle_state[injured].hp
		var health_max: int = main.hero_battle_state[injured].max_hp
		var gold_before: int = main.wallet_gold
		assert_owned_bars(main, original, faction + " initial")
		for cycle in 3:
			var previous: Array = main.hero_hp_bars.values().duplicate()
			main._open_hero_menu(); await settle()
			var next_ids: Array = original.slice(0, 9) if cycle % 2 == 0 else original.duplicate()
			main._restore_deployed_heroes(next_ids)
			# Cover both the hidden hunt tick and direct Home reconciliation.
			if cycle != 1: main._advance_auto_hunt(0.05)
			main._open_home(); await settle()
			var freed := true
			for bar in previous: freed = freed and not is_instance_valid(bar)
			check(freed, faction + " replacement frees every old health bar cycle " + str(cycle))
			assert_owned_bars(main, next_ids, faction + " reconciled " + str(cycle))
			var state: Dictionary = main.hero_battle_state[injured]
			check(absf(float(state.hp) / float(state.max_hp) - float(health_before) / float(health_max)) < 0.001, faction + " party edits preserve existing injury cycle " + str(cycle))
			check(main.content_root.get_instance_id() == hunt_id and main.wallet_gold == gold_before and not main.combat_running, faction + " same paused hunt and wallet survive replacement cycle " + str(cycle))
		await dispose(main)
	done("HUNT_ACTOR_LIFETIME")
