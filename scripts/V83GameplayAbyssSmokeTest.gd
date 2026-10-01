extends SceneTree

## Actual existing hero AI, skills, guardian and HP paths; no forced wins,
## synthetic score calls, manually shortened timers, or enemy HP overrides.
## A leveled fixture is NOT beginner difficulty certification.
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 abyss actual battle: " + label)

func _run() -> void:
	var main = preload("res://scenes/PortraitMain.tscn").instantiate()
	var save_path: String = "user://v80-4-abyss-battle-%d.json" % OS.get_process_id()
	main.save_state_path = save_path
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.set_process(false)
	main.combat_effects_enabled = false
	main.sound_effects_enabled = false
	main.battle_speed = 1.0
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main.current_zone_id = "gray_meadow"
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	for hero in main.deployed_heroes: main.hero_progress[str(hero["id"])] = {"level": 60, "xp": 0}
	main._offline_checked = true
	main.weekly_content_key = main._week_key()
	main.weekly_trial_runs = 0
	main.weekly_trial_best = 0
	main.wallet_gold = 100
	main.wallet_gems = 10
	main.daily_dungeon_day = main._today_key()
	main.daily_dungeon_runs = 2
	main.set_meta("content_meta_tab", "weekly")
	main._build_meta_hub_screen()
	await process_frame
	var entry: Dictionary = main._weekly_entry_context()
	var before: Array = [main.idle_stage, main.idle_stage_kills, JSON.stringify(main.loot_inventory), main.daily_dungeon_runs,
		JSON.stringify(main.daily_dungeon_clears), main.tower_floor, main.tower_best_floor,
		main.unclaimed_gold, main.unclaimed_xp, main.idle_chest_gold, main.idle_chest_xp, JSON.stringify(main.raid_clears)]
	var button = main.find_child("DungeonEnterButton", true, false)
	_check(button != null and not button.disabled, "actual entry UI reachable")
	if button != null: button.emit_signal("pressed")
	_check(main.active_screen == "combat" and main.challenge_session != null, "weekly entry keeps combat screen")
	_check(main.wallet_gold == 100 and main.weekly_trial_runs == 0, "no immediate reward")
	_check(not main._run_weekly_trial(entry), "duplicate entry blocked")
	if main.challenge_session != null:
		main._application_suspended = true
		main._advance_auto_hunt(0.5)
		_check(main.challenge_session.elapsed == 0.0 and main.challenge_session.damage_score == 0, "suspension pauses score and clock")
		main._application_suspended = false
	var ticks: int = 0
	var observed_damage: int = 0
	var lowest_hp: Dictionary = {}
	var boss_ids: Dictionary = {}
	while main.challenge_session != null and ticks < 2800:
		# Keep actual dictionary references even if settlement clears the view.
		var enemies: Array = main.enemy_wave.duplicate()
		for enemy in enemies:
			var id: String = str(enemy["id"])
			if not lowest_hp.has(id): lowest_hp[id] = int(enemy["hp"])
			if bool(enemy.get("challenge_boss", false)): boss_ids[id] = true
		main._advance_auto_hunt(1.0 / 30.0)
		for enemy in enemies:
			var id: String = str(enemy["id"])
			var after: int = maxi(0, int(enemy["hp"]))
			observed_damage += maxi(0, int(lowest_hp[id]) - after)
			lowest_hp[id] = mini(int(lowest_hp[id]), after)
		ticks += 1
		if ticks % 30 == 0: await process_frame
	_check(main.challenge_session == null and main.active_screen == "meta_hub", "returns after actual battle")
	var result: Dictionary = main.get_meta("last_dungeon_result", {})
	_check(bool(result.get("settled", false)), "leveled fixture survives full trial")
	_check(is_equal_approx(float(result.get("elapsed", 0)), 90.0), "actual 90 game-seconds, not power outcome")
	_check(observed_damage > 0 and int(result.get("score", -1)) == observed_damage, "score equals observed real HP reduction")
	_check(main.weekly_trial_runs == 1 and main.weekly_trial_best == observed_damage, "weekly record once")
	var report: Dictionary = main.get_meta("last_challenge_report", {})
	_check(report.get("total_damage", -1) == observed_damage and report.get("score", -1) == observed_damage, "new report matches independent HP trace and authoritative abyss score")
	_check(report.get("actors", []).size() == 3 and is_equal_approx(float(report.get("elapsed", 0)), 90.0), "report covers three actual heroes and full trial")
	var sum_damage: int = int(report.get("support_damage", 0)) + int(report.get("unknown_damage", 0))
	for row in report.get("actors", []): sum_damage += int(row.get("damage", 0))
	_check(sum_damage == observed_damage, "hero plus guardian totals equal actual abyss score")

	_check(main.wallet_gold == 1700 and main.wallet_gems == 28, "exact first completion reward")
	_check(boss_ids.size() >= 1, "actual boss appeared")
	_check(before == [main.idle_stage, main.idle_stage_kills, JSON.stringify(main.loot_inventory), main.daily_dungeon_runs,
		JSON.stringify(main.daily_dungeon_clears), main.tower_floor, main.tower_best_floor,
		main.unclaimed_gold, main.unclaimed_xp, main.idle_chest_gold, main.idle_chest_xp, JSON.stringify(main.raid_clears)], "no field/daily/tower/raid reward leakage")
	_check(not main._run_weekly_trial(entry), "stale UI cannot consume next attempt")
	var fresh: Dictionary = main._weekly_entry_context()
	_check(main._run_weekly_trial(fresh), "next legitimate attempt can start")
	main._build_lobby_screen()
	_check(main.challenge_session == null and main.weekly_trial_runs == 1 and main.wallet_gold == 1700, "leave cancels without score or reward")
	# Stop playback while players still exist; allow the audio thread to retire Ogg buffers.
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	await process_frame
	main.free()
	await create_timer(0.35).timeout
	await process_frame
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	await process_frame
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("v83_gameplay_abyss checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
