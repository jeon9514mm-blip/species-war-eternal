extends SceneTree

const RULES = preload("res://scripts/TowerBattleRules.gd")
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 actual tower battle: " + label)

func _run() -> void:
	for floor_number in [1, 5, 6]:
		var main = preload("res://scenes/PortraitMain.tscn").instantiate()
		var save_path: String = "user://v80-3-tower-battle-%d-%d.json" % [floor_number, OS.get_process_id()]
		main.save_state_path = save_path
		root.add_child(main)
		await process_frame
		main.set_physics_process(false)
		main.combat_effects_enabled = false
		main.sound_effects_enabled = false
		main.battle_speed = 1.0
		main.party_slot_legacy_cap = 10
		main.selected_faction = "aurelia"
		main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
		for hero in main.deployed_heroes:
			main.hero_progress[str(hero["id"])] = {"level": 60, "xp": 0}
		main._offline_checked = true
		main.tower_floor = floor_number
		main.tower_best_floor = floor_number - 1
		main.daily_dungeon_day = main._today_key()
		main.daily_dungeon_runs = 2
		main.daily_dungeon_clears = {"aurelia:gold_rush:0": true}
		main.wallet_gold = 100
		main.wallet_gems = 10
		main.set_meta("content_meta_tab", "tower")
		main._build_meta_hub_screen()
		await process_frame
		var original_context: Dictionary = main._tower_entry_context()
		var before: Array = [main.idle_stage, main.idle_stage_kills, JSON.stringify(main.loot_inventory), main.daily_dungeon_runs,
			JSON.stringify(main.daily_dungeon_clears), main.unclaimed_gold, main.unclaimed_xp,
			main.idle_chest_gold, main.idle_chest_xp, main.weekly_trial_runs, JSON.stringify(main.raid_clears)]
		var enter = main.find_child("DungeonEnterButton", true, false)
		_check(enter != null and not enter.disabled, "tower entry reachable")
		if enter != null: enter.emit_signal("pressed")
		_check(main.active_screen == "combat" and main.challenge_session != null, "button keeps actual combat open")
		_check(main.tower_floor == floor_number and main.wallet_gold == 100 and main.wallet_gems == 10, "no immediate entry reward")
		_check(not main._challenge_tower(original_context), "double entry blocked during battle")
		if main.challenge_session != null:
			main._application_suspended = true
			main._advance_auto_hunt(0.5)
			_check(main.challenge_session.elapsed == 0.0, "suspending app pauses battle clock")
			main._application_suspended = false
		var ticks: int = 0
		var boss_seen: bool = false
		var wave_tokens: Dictionary = {}
		# Real existing AI, skill, guardian, movement and HP paths. No forced win,
		# direct wave-completion call, or enemy HP override in this integration test.
		while main.challenge_session != null and ticks < 3000:
			wave_tokens[int(main.hunt_ai.encounter_id)] = true
			for enemy in main.enemy_wave:
				if bool(enemy.get("challenge_boss", false)): boss_seen = true
			main._advance_auto_hunt(1.0 / 30.0)
			ticks += 1
			if ticks % 30 == 0: await process_frame
		_check(main.challenge_session == null, "combat terminates by deadline")
		var reward: Dictionary = RULES.reward(floor_number)
		_check(main.tower_floor == floor_number + 1 and main.tower_best_floor == floor_number, "leveled actual-AI fixture clears floor")
		_check(main.wallet_gold == 100 + int(reward["gold"]) and main.wallet_gems == 10 + int(reward["gems"]), "exact one-time tower reward")
		_check(boss_seen == RULES.is_boss_floor(floor_number), "fifth floor actually spawned boss")
		_check(wave_tokens.size() == int(RULES.plan(floor_number)["required_waves"]), "all planned waves used")
		_check(before == [main.idle_stage, main.idle_stage_kills, JSON.stringify(main.loot_inventory), main.daily_dungeon_runs,
			JSON.stringify(main.daily_dungeon_clears), main.unclaimed_gold, main.unclaimed_xp,
			main.idle_chest_gold, main.idle_chest_xp, main.weekly_trial_runs, JSON.stringify(main.raid_clears)], "no field, daily, weekly or raid reward leakage")
		_check(not main._challenge_tower(original_context), "old UI request cannot enter next floor")
		var next_floor: int = int(main.tower_floor)
		var gold_after: int = int(main.wallet_gold)
		_check(main._challenge_tower(main._tower_entry_context()), "fresh request can retry or enter next floor")
		main._build_lobby_screen()
		_check(main.challenge_session == null and main.tower_floor == next_floor and main.wallet_gold == gold_after, "screen exit cancels without payout")
		# Let stopped Ogg playback retire before destroying its players.
		if is_instance_valid(main.presentation_runtime): main.presentation_runtime.audio.shutdown()
		await create_timer(0.5).timeout
		await process_frame
		main.free()
		# v82: audio playback teardown is asynchronous even with the Dummy driver.
		await create_timer(0.3).timeout
		await process_frame
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(save_path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("v80_tower_actual_battle checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
