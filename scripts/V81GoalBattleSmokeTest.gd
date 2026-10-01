extends SceneTree
## Real AI battle loops with level-60 three-hero fixtures. No enemy HP edits,
## synthetic victories, shortened timers or mocked mission events here.
const SERVICE = preload("res://scripts/LongTermGoalsService.gd")
const STATE = preload("res://scripts/LongTermGoalState.gd")
var checks: int = 0
var failures: Array[String] = []
var main: Node
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func count(event: String, scope: String = "achievement") -> int:
	SERVICE.refresh(main)
	return STATE.metric_value(main.long_term_goals, str(main.selected_faction), scope, event)
func settle() -> void:
	for frame in 4: await process_frame
func _run() -> void:
	main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://v81-real-battle-%d.json" % OS.get_process_id()
	root.add_child(main); await settle()
	main.set_physics_process(false); main.set_process(false)
	main.combat_effects_enabled = false; main.sound_effects_enabled = false
	main.selected_faction = "aurelia"; main.party_slot_legacy_cap = 10
	main.idle_stage = 2; main._offline_checked = true
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	for hero in main.deployed_heroes: main.hero_progress[str(hero["id"])] = {"level": 60, "xp": 0}
	main._build_combat_screen(); await settle()
	check(count("hunt_packs") == 0, "entry never increments hunt missions")
	var ticks: int = 0
	while count("hunt_packs") == 0 and ticks < 2000:
		main._advance_auto_hunt(1.0 / 30.0); ticks += 1
		if ticks % 30 == 0: await process_frame
	print("v81_phase_hunt ticks=%d" % ticks)
	var hunt: int = count("hunt_packs")
	check(hunt > 0, "actual AI hunt settlement increments missions")
	check(count("hunt_packs", "daily") == hunt and count("hunt_packs", "weekly") == hunt, "hunt event reaches all intended ledgers")
	main._finish_hunt_target()
	check(count("hunt_packs") == hunt, "replayed hunt finish cannot recount")
	main._build_lobby_screen(); await settle()
	main.daily_dungeon_day = main._today_key(); main.daily_dungeon_runs = 0
	check(main._run_daily_dungeon("gold_rush"), "actual daily enters")
	check(count("daily_clear") == 0, "daily entry not completion")
	ticks = 0
	while main.challenge_session != null and ticks < 2000:
		main._advance_auto_hunt(1.0 / 30.0); ticks += 1
		if ticks % 30 == 0: await process_frame
	print("v81_phase_daily ticks=%d" % ticks)
	check(main.challenge_session == null and main.daily_dungeon_runs == 1, "actual daily fixture wins")
	check(count("daily_clear") == 1 and count("daily_clear", "daily") == 1, "settled daily adds exactly one event")
	check(count("hunt_packs") == hunt, "daily enemies never count as field hunting")
	main.CHALLENGE_DRIVER.finish(main)
	check(count("daily_clear") == 1, "daily duplicate completion neutral")
	check(main._run_daily_dungeon("survival"), "another daily can enter")
	main._build_lobby_screen(); await settle()
	check(count("daily_clear") == 1, "cancelled challenge gives no mission credit")
	main.tower_floor = 1; main.tower_best_floor = 0
	check(main._challenge_tower(main._tower_entry_context()), "actual tower enters")
	ticks = 0
	while main.challenge_session != null and ticks < 2800:
		main._advance_auto_hunt(1.0 / 30.0); ticks += 1
		if ticks % 30 == 0: await process_frame
	print("v81_phase_tower ticks=%d" % ticks)
	check(main.tower_floor == 2 and main.tower_best_floor == 1, "actual tower first-floor victory")
	check(count("tower_clear") == 1 and count("tower_clear", "weekly") == 1, "tower completion credited once")
	main.weekly_content_key = main._week_key(); main.weekly_trial_runs = 0; main.weekly_trial_best = 0
	check(main._run_weekly_trial(main._weekly_entry_context()), "actual abyss enters")
	ticks = 0
	while main.challenge_session != null and ticks < 2800:
		main._advance_auto_hunt(1.0 / 30.0); ticks += 1
		if ticks % 30 == 0: await process_frame
	print("v81_phase_abyss ticks=%d" % ticks)
	check(main.weekly_trial_runs == 1 and main.weekly_trial_best > 0, "real 90-second abyss succeeds")
	check(count("abyss_clear") == 1 and count("abyss_clear", "weekly") == 1, "abyss success credited once")
	check(count("challenge_clear", "daily") == 3, "combined challenge mission uses settled content")
	check(count("hunt_packs") == hunt, "tower/abyss do not leak field hunt progress")
	var receipt: Dictionary = main._claim_goal("daily", "daily_challenge_3", main._goal_claim_context("daily"))
	check(receipt.get("ok", false) and receipt["gold"] == 200 and receipt["gems"] == 3, "real completion reaches claimable mission reward")
	var before: Dictionary = main.long_term_goals.duplicate(true)
	main._save_idle_state(); main._load_idle_state()
	check(main.long_term_goals == before, "real scene save reload preserves mission progress and claim")
	check(not main._claim_goal("daily", "daily_challenge_3", main._goal_claim_context("daily")).get("ok", false), "reload cannot reclaim")
	main.selected_faction = "noxfera"
	check(count("daily_clear") == 0 and count("abyss_clear") == 0, "permanent goals do not copy to opposite faction")
	check(count("challenge_clear", "daily") == 3, "period missions deliberately shared, not reset by faction")
	var ctx: Dictionary = main._goal_claim_context("daily")
	check(not main._claim_goal("daily", "daily_challenge_3", ctx).get("ok", false), "other faction cannot farm claimed daily reward")
	# Check a real second-faction daily run with that faction's own roster.
	var roster: Array = main._hero_roster_for_faction()
	var ids: Array[String] = []
	for hero: Dictionary in roster.slice(0, 3): ids.append(str(hero["id"]))
	main._restore_deployed_heroes(ids)
	for hero in main.deployed_heroes: main.hero_progress[str(hero["id"])] = {"level": 60, "xp": 0}
	check(main._run_daily_dungeon("gold_rush"), "opposite faction legitimate daily enters")
	ticks = 0
	while main.challenge_session != null and ticks < 2000:
		main._advance_auto_hunt(1.0 / 30.0); ticks += 1
		if ticks % 30 == 0: await process_frame
	print("v81_phase_noxfera_daily ticks=%d" % ticks)
	check(main.daily_dungeon_runs == 2 and count("daily_clear") == 1, "opposite faction victory has own permanent count")
	check(main.long_term_goals["factions"]["aurelia"]["totals"]["daily_clear"] == 1, "first faction counter preserved")
	main.free(); await settle()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	print("v81_goal_battle checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
