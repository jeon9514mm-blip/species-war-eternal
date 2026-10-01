extends SceneTree

# Real portrait launch/resume paths and calendar transitions that used to lose
# pending idle time or reopen exhausted daily/weekly rewards after clock rollback.
class CalendarMain:
	extends "res://scripts/Main.gd"
	var test_day := "2026-09-28"
	var test_week := "2960"
	func _ready() -> void:
		pass
	func _today_key() -> String:
		return test_day
	func _week_key() -> String:
		return test_week
	func _show_toast(_message: String) -> void:
		pass

var checks := 0
var failures: Array[String] = []
var test_root := "user://v51-persistence-%d" % OS.get_process_id()
var store := SaveStore.new()

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V51 persistence: " + label)

func _launch(name_value: String, data: Dictionary):
	var path := test_root.path_join(name_value + ".json")
	_check(store.write_save(path, data).get("ok", false), "fixture " + name_value + " saved")
	var main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = path
	root.add_child(main)
	main.set_physics_process(false)
	for _frame in 3:
		await process_frame
	return main

func _test_offline_lifecycle() -> void:
	var main = await _launch("startup", {
		"selected_faction": "aurelia", "deployed_hero_ids": ["leonhardt"],
		"idle_stage": 10, "last_idle_timestamp": int(Time.get_unix_time_from_system()) - 600,
		"hero_progress": {"leonhardt": {"level": 5, "xp": 30}},
		"hero_equipment": {"leonhardt": {"weapon": 4, "armor": 3, "accessory": 2}},
		"wallet_gold": 250, "wallet_gems": 25
	})
	_check(main.active_screen == "title", "startup settlement keeps the title screen")
	_check(main._offline_checked and main.offline_reward_seconds >= 600 and main.unclaimed_gold > 0, "loaded expedition settles idle rewards before a menu can save")
	_check(main.hero_equipment["leonhardt"]["weapon"] >= 4 and main.wallet_gems == 25, "idle settlement preserves enhanced equipment and gems")
	var pending: int = main.unclaimed_gold + main.idle_chest_gold
	var growth_before := JSON.stringify(main.hero_progress)
	main._build_lobby_screen()
	main._save_party_preset(0)
	main._build_combat_screen()
	main.set_physics_process(false)
	_check(main.unclaimed_gold + main.idle_chest_gold == pending and JSON.stringify(main.hero_progress) == growth_before, "lobby save and first hunt cannot lose or duplicate startup rewards")
	main._build_lobby_screen()
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	main.last_idle_timestamp -= 120
	var paused_time: int = main.last_idle_timestamp
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(main.last_idle_timestamp == paused_time, "duplicate pause cannot overwrite pending menu idle time")
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(main.unclaimed_gold + main.idle_chest_gold > pending and main.offline_reward_seconds >= 120, "resume from the lobby also settles pending idle rewards")
	_check(main.active_screen == "lobby" and main.content_root.get_node_or_null("OfflineRewardPopup") == null, "menu resume preserves the screen without combat-only reward popup")
	pending = main.unclaimed_gold + main.idle_chest_gold
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main._calculate_offline_reward()
	_check(main.unclaimed_gold + main.idle_chest_gold == pending, "repeated resume and reward callbacks settle once")
	main._load_idle_state()
	_check(not main._offline_checked, "loading another state invalidates the previous settlement guard")
	main._calculate_offline_reward()
	_check(main.unclaimed_gold + main.idle_chest_gold == pending, "reloaded checkpoint prevents duplicate offline rewards")
	var aurelia_growth := JSON.stringify(main.hero_progress["leonhardt"])
	var aurelia_rations: int = main.faction_war_state.rations
	main._select_faction("noxfera")
	_check(main.deployed_heroes.is_empty() and JSON.stringify(main.hero_progress["leonhardt"]) == aurelia_growth, "switching factions after startup settlement preserves original hero growth")
	_check(int(main.faction_world_snapshots["aurelia"]["war"]["rations"]) == aurelia_rations and not main.pet_progress.has("noxfera"), "offline supplies and pet growth remain with the saved faction")
	main.active_screen = ""
	main.free()

	var empty = await _launch("empty", {"selected_faction": "aurelia", "deployed_hero_ids": [], "last_idle_timestamp": int(Time.get_unix_time_from_system()) - 3600})
	_check(empty.unclaimed_gold == 0 and empty.unclaimed_xp == 0 and empty.deployed_heroes.is_empty(), "empty saved expedition cannot earn idle rewards")
	empty.free()

func _test_calendar_rollback() -> void:
	var main := CalendarMain.new()
	main.save_state_path = test_root.path_join("calendar.json")
	root.add_child(main)
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.idle_stage = 100
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	for hero in main.deployed_heroes:
		main.hero_progress[str(hero["id"])] = {"level": 50, "xp": 0}
	main._offline_checked = true
	var button := Button.new()
	var label := Label.new()
	main.add_child(button)
	main.add_child(label)

	main._claim_daily_reward(button, label)
	_check(main.wallet_gems == 30 and main.daily_reward_claimed_day == "2026-09-28", "daily reward initially pays once")
	main._claim_daily_reward(button, label)
	main.test_day = "2026-09-27"
	main._claim_daily_reward(button, label)
	_check(main.wallet_gems == 30 and main.daily_reward_claimed_day == "2026-09-28", "same and earlier day cannot pay daily reward again")
	main.test_day = "2026-09-29"
	main._claim_daily_reward(button, label)
	_check(main.wallet_gems == 60 and main.daily_reward_claimed_day == "2026-09-29", "next calendar day unlocks the next reward")

	main.test_day = "2026-09-28"
	for _claim in 3:
		main._claim_rewarded_ad(button, label)
	var gems_before := main.wallet_gems
	main.test_day = "2026-09-27"
	main._claim_rewarded_ad(button, label)
	_check(main.wallet_gems == gems_before and main.rewarded_ad_claimed_count == 3 and main.rewarded_ad_day == "2026-09-28", "clock rollback cannot refill support reward allowance")
	main.test_day = "2026-09-29"
	main._claim_rewarded_ad(button, label)
	_check(main.wallet_gems == gems_before + 5 and main.rewarded_ad_claimed_count == 1, "next day resets support rewards exactly once")

	main.test_day = "2026-09-28"
	for _run_index in 3:
		_check(main._run_daily_dungeon(), "daily dungeon has its normal allowance")
		_advance_daily_fixture(main)
		_check(main.daily_dungeon_runs == _run_index + 1, "daily allowance increments after actual combat")
	var gold_before := main.wallet_gold
	main.test_day = "2026-09-27"
	_check(not main._run_daily_dungeon(), "clock rollback cannot reopen exhausted daily dungeon")
	_check(main.daily_dungeon_runs == 3 and main.daily_dungeon_day == "2026-09-28" and main.wallet_gold == gold_before, "daily checkpoint and wallet stay unchanged on rollback")
	main.test_day = "2026-09-29"
	_check(main._run_daily_dungeon() and main.daily_dungeon_runs == 0, "forward day resets allowance before battle")
	_advance_daily_fixture(main)
	_check(main.daily_dungeon_runs == 1, "forward day battle settles normally")

	for _run_index in 5:
		_check(main._run_weekly_trial(), "weekly trial has its normal allowance")
		_advance_weekly_fixture(main)
		_check(main.weekly_trial_runs == _run_index + 1, "weekly quota increments only after full battle")
	gold_before = main.wallet_gold
	main.test_week = "2959"
	_check(not main._run_weekly_trial(), "earlier week cannot refill weekly attempts")
	_check(main.weekly_trial_runs == 5 and main.weekly_content_key == "2960" and main.wallet_gold == gold_before, "weekly rollback keeps count, checkpoint, and gold")
	main.test_week = "2961"
	_check(main._run_weekly_trial() and main.weekly_trial_runs == 0, "forward week resets before entry without reward")
	_advance_weekly_fixture(main)
	_check(main.weekly_trial_runs == 1, "forward week settles after actual battle")
	main.free()

func _test_calendar_schema() -> void:
	for valid in ["2026-09-28", "2024-02-29", "2000-02-29", "2099-12-31"]:
		_check(SaveValidation.day_key(valid) == valid, "valid calendar checkpoint preserved " + valid)
	for invalid in [null, [], {}, 20260928, "", "zzz", "2026-02-29", "1900-02-29", "2026-04-31", "2026-00-01", "2026-13-01", "2026-01-00", "2026-1-01", "2026-01-1+", "0000-01-01"]:
		_check(SaveValidation.day_key(invalid).is_empty(), "invalid calendar checkpoint rejected " + str(invalid))
	for invalid in [null, [], {}, "zzz", "2960.5", "1e20", "9999999999999999999999999"]:
		_check(SaveValidation.week_key(invalid).is_empty(), "invalid weekly checkpoint rejected " + str(invalid))
	_check(SaveValidation.week_key("2960") == "2960" and SaveValidation.week_key("002960") == "2960" and SaveValidation.week_key("-1") == "-1", "valid week keys preserve their numeric checkpoint")
	var raw := {"daily_reward_claimed_day": "2026-09-28", "rewarded_ad_day": "2026-02-29", "daily_dungeon_day": "bad", "weekly_content_key": "002960", "daily_dungeon_runs": 3, "weekly_trial_runs": 5, "wallet_gold": 9876, "hero_progress": {"leonhardt": {"level": 20, "xp": 321}}, "hero_equipment": {"leonhardt": {"weapon": 10, "armor": 7, "accessory": 4}}}
	var clean := SaveValidation.sanitize(raw, ["gray_meadow"])
	_check(clean["daily_reward_claimed_day"] == "2026-09-28" and clean["rewarded_ad_day"] == "" and clean["daily_dungeon_day"] == "" and clean["weekly_content_key"] == "2960", "save restoration validates calendar fields before ordered comparison")
	_check(clean["wallet_gold"] == 9876 and clean["hero_progress"] == raw["hero_progress"] and clean["hero_equipment"] == raw["hero_equipment"], "calendar repair preserves player gold, levels, XP, and upgraded equipment")
	_check(raw["daily_dungeon_day"] == "bad" and raw["weekly_content_key"] == "002960", "calendar normalization leaves source data untouched")

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for entry in directory.get_files():
		directory.remove(entry)
	for entry in directory.get_directories():
		_remove_tree(path.path_join(entry))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root))
	_test_calendar_schema()
	await _test_offline_lifecycle()
	_test_calendar_rollback()
	_remove_tree(test_root)
	print("v51_persistence_lifecycle_smoke_test checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _advance_daily_fixture(main: Node) -> void:
	# Run the real combat adapter rather than assuming an instant power check.
	var ticks: int = 0
	while main.challenge_session != null and ticks < 2000:
		main._advance_auto_hunt(1.0 / 30.0)
		ticks += 1
	_check(main.challenge_session == null, "daily fixture reaches a result")

func _advance_weekly_fixture(main: Node) -> void:
	var ticks: int = 0
	while main.challenge_session != null and ticks < 2800:
		main._advance_auto_hunt(1.0 / 30.0)
		ticks += 1
	_check(main.challenge_session == null, "weekly fixture reaches a result")
