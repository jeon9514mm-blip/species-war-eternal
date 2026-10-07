extends SceneTree

const PROGRESS = preload("res://scripts/progression/DailyDungeonProgress.gd")
const RULES = preload("res://scripts/progression/DailyDungeonBattleRules.gd")
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 modes battle: " + label)

func _run() -> void:
	for variant in RULES.VARIANTS:
		var main = preload("res://scenes/PortraitMain.tscn").instantiate()
		var save_path: String = "user://v80-2-battle-%s-%d.json" % [variant, OS.get_process_id()]
		main.save_state_path = save_path
		root.add_child(main)
		await process_frame
		main.set_physics_process(false)
		main.combat_effects_enabled = false
		main.sound_effects_enabled = false
		main.party_slot_legacy_cap = 10
		main.selected_faction = "aurelia"
		main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
		for hero in main.deployed_heroes:
			main.hero_progress[str(hero["id"])] = {"level": 60, "xp": 0}
		main._offline_checked = true
		main.daily_dungeon_day = main._today_key()
		main.daily_dungeon_runs = 0
		main.daily_dungeon_clears = {}
		main.wallet_gold = 100
		main.wallet_xp = 0
		main.unclaimed_gold = 0
		main.unclaimed_xp = 0
		main.idle_chest_gold = 0
		main.idle_chest_xp = 0
		var field_before: Array = [main.idle_stage, main.idle_stage_kills, JSON.stringify(main.loot_inventory)]
		_check(main._run_daily_dungeon(variant), variant + " enters actual combat")
		_check(main.wallet_gold == 100 and main.daily_dungeon_runs == 0, "no entry payout")
		if main.challenge_session != null:
			main._application_suspended = true
			main._advance_auto_hunt(0.5)
			_check(main.challenge_session.elapsed == 0.0, "suspend pauses challenge clock")
			main._application_suspended = false
		# Existing game AI/skills/HP only. No force win and no enemy-HP edits.
		var ticks: int = 0
		while main.challenge_session != null and ticks < 2000:
			main._advance_auto_hunt(1.0 / 30.0)
			ticks += 1
			if ticks % 30 == 0:
				await process_frame
		_check(main.challenge_session == null, variant + " terminates")
		_check(main.daily_dungeon_runs == 1 and main.wallet_gold == 1050 and main.wallet_xp == 350, variant + " leveled real-AI fixture wins")
		_check(PROGRESS.can_sweep(main.daily_dungeon_clears, "aurelia", variant, 0), "direct victory unlocks same tier")
		_check(not PROGRESS.can_sweep(main.daily_dungeon_clears, "aurelia", variant, 1), "higher tier still requires real clear")
		_check(field_before == [main.idle_stage, main.idle_stage_kills, JSON.stringify(main.loot_inventory)], "no field progress or gear reward leakage")
		main.set_meta("daily_dungeon_variant", variant)
		main._build_meta_hub_screen()
		await process_frame
		_check(main.find_child("DailyDungeonModeTabs", true, false) != null, "portrait mode selection reachable")
		var sweep_button = main.find_child("DungeonSweepButton", true, false)
		_check(sweep_button != null and sweep_button.disabled, "next-tier sweep remains locked in UI")
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
	print("v80_daily_modes_battle checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
