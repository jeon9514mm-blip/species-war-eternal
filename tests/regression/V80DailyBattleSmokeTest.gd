extends SceneTree

const DIRECTOR = preload("res://scripts/combat/ChallengeBattleDirector.gd")
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 daily: " + label)

func _run() -> void:
	var main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://v80-daily-%d.json" % OS.get_process_id()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.combat_effects_enabled = false
	main.sound_effects_enabled = false
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	for hero in main.deployed_heroes:
		main.hero_progress[str(hero["id"])] = {"level": 20, "xp": 0}
	main._offline_checked = true
	main.daily_dungeon_day = main._today_key()
	main.daily_dungeon_runs = 0
	main.wallet_gold = 100
	main.wallet_xp = 0
	var stage_before: int = main.idle_stage
	var stage_kills_before: int = main.idle_stage_kills
	var gold_before: int = main.wallet_gold
	var inventory_before: String = JSON.stringify(main.loot_inventory)
	_check(main._run_daily_dungeon(), "daily button starts an encounter")
	_check(main.active_screen == "combat" and main.challenge_session != null, "actual field view connected")
	_check(main.daily_dungeon_runs == 0 and main.wallet_gold == gold_before, "entry is not an instant clear or payout")
	_check(not main._run_daily_dungeon(), "double click cannot replace a running encounter")
	main._application_suspended = true
	main._advance_auto_hunt(0.5)
	_check(main.challenge_session.elapsed == 0.0, "app suspend does not advance dungeon clock")
	main._application_suspended = false
	main.combat_running = false
	main._advance_auto_hunt(0.5)
	_check(main.challenge_session.elapsed == 0.0, "pause does not advance dungeon clock")
	main.combat_running = true
	# Real AI/skills tick here. No direct HP edit or force-victory operation.
	var ticks: int = 0
	while main.challenge_session != null and ticks < 2000:
		main._advance_auto_hunt(1.0 / 30.0)
		ticks += 1
	_check(main.challenge_session == null, "battle reaches a terminal outcome")
	_check(main.daily_dungeon_runs == 1 and main.wallet_gold == gold_before + 950, "leveled fixture wins and pays exactly once")
	_check(main.wallet_xp == 350, "daily XP value is unchanged")
	_check(main.idle_stage == stage_before and main.idle_stage_kills == stage_kills_before, "dungeon does not advance field stages")
	_check(JSON.stringify(main.loot_inventory) == inventory_before, "dungeon waves do not roll ordinary field gear")
	DIRECTOR.finish(main)
	_check(main.wallet_gold == gold_before + 950, "late finish cannot pay again")
	gold_before = main.wallet_gold
	_check(main._run_daily_dungeon(), "next run can start")
	var cancelled: ChallengeBattleSession = main.challenge_session
	main._build_meta_hub_screen()
	_check(cancelled.state == ChallengeBattleSession.State.CANCELLED, "navigation cancels encounter")
	_check(main.daily_dungeon_runs == 1 and main.wallet_gold == gold_before, "cancel awards and consumes nothing")
	_check(main._run_daily_dungeon(), "can retry cancelled encounter")
	for id in main.hero_battle_state:
		main.hero_battle_state[id]["hp"] = 0
	main._advance_auto_hunt(1.0 / 30.0)
	_check(main.challenge_session == null and main.daily_dungeon_runs == 1, "total defeat does not auto-revive or consume clear allowance")
	_check(main.wallet_gold == gold_before, "defeat cannot pay")
	# Explicitly stop playback while the game is still attached, then release
	# the observed cancelled session before quitting the test SceneTree.
	if is_instance_valid(main.presentation_runtime): main.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	await process_frame
	cancelled = null
	main.free()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.5).timeout
	await process_frame
	if failures.is_empty():
		print("v80_daily_battle_smoke_test_ok checks=%d" % checks)
		quit(0)
	else:
		quit(1)
