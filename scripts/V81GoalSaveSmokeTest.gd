extends SceneTree
const S = preload("res://scripts/LongTermGoalState.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _init() -> void:
	var old: Dictionary = {"save_version": 34, "wallet_gold": 4321, "wallet_gems": 123, "quest_claimed": {"stage5": true},
		"selected_faction": "aurelia", "daily_dungeon_day": "2026-10-01", "daily_dungeon_runs": 2, "tower_floor": 21, "tower_best_floor": 20,
		"weekly_content_key": "2960", "weekly_trial_runs": 4, "weekly_trial_best": 100, "weekly_trial_score_version": 1,
		"daily_dungeon_clears": {"aurelia:gold_rush:0": true}, "hero_progress": {"leonhardt": {"level": 20, "xp": 1}}}
	var migrated: Dictionary = SaveValidation.sanitize(old, ["gray_meadow"])
	check(SaveStore.VERSION == 37, "current formation-aware schema version")
	check(migrated["quest_claimed"] == old["quest_claimed"], "legacy quest receipt preserved")
	check(migrated["wallet_gold"] == 4321 and migrated["wallet_gems"] == 123, "migration never grants money")
	check(migrated["daily_dungeon_runs"] == 2 and migrated["weekly_trial_runs"] == 4, "migration never restores allowances")
	check(migrated["tower_best_floor"] == 20 and migrated["weekly_trial_best"] == 100, "tower and actual abyss record preserved")
	check(migrated["daily_dungeon_clears"] == old["daily_dungeon_clears"], "sweep unlock preserved")
	var goals: Dictionary = migrated["long_term_goals"]
	check(goals["factions"]["aurelia"]["totals"]["daily_clear"] == 0, "no invented historical event counts")
	S.record(goals, "aurelia", "hunt_packs", 100, "2026-10-01", "2960")
	S.claim(goals, "aurelia", "achievement", "hunt_100", {"scope": "achievement", "faction": "aurelia"}, "2026-10-01", "2960")
	goals["factions"]["aurelia"]["title"] = "hunt_100"
	S.claim(goals, "aurelia", "daily", "daily_hunt_10", {"scope": "daily", "faction": "aurelia", "key": "2026-10-01"}, "2026-10-01", "2960")
	var file: String = "user://v81-goal-save-%d.json" % OS.get_process_id()
	var store: SaveStore = SaveStore.new()
	check(store.write_save(file, migrated).get("ok", false), "real goal save write")
	var read: Dictionary = store.read_save(file)
	check(read.get("ok", false), "real goal save read")
	var restored: Dictionary = SaveValidation.sanitize(read.get("data", {}), ["gray_meadow"])
	check(restored["long_term_goals"] == goals, "counters claims titles survive real disk roundtrip")
	check(not S.claim(restored["long_term_goals"], "aurelia", "daily", "daily_hunt_10", {"scope": "daily", "faction": "aurelia", "key": "2026-10-01"}, "2026-10-01", "2960")["ok"], "no replay after reload")
	check(restored["quest_claimed"] == old["quest_claimed"] and restored["weekly_trial_runs"] == 4, "old progress still unchanged after write")
	check(SaveValidation.sanitize(restored, ["gray_meadow"])["long_term_goals"] == restored["long_term_goals"], "migration idempotent")
	check(store.write_save(file, restored).get("ok", false), "second write creates recovery backup")
	var damaged: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	damaged.store_string("{broken"); damaged.close()
	var fallback: Dictionary = store.read_save(file)
	check(fallback.get("ok", false) and fallback.get("source", "") == "backup", "actual broken primary fallback")
	check(SaveValidation.sanitize(fallback["data"], ["gray_meadow"])["long_term_goals"]["daily"]["claimed"].get("daily_hunt_10", false), "backup retains claimed ledger")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt"]:
		if FileAccess.file_exists(file + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(file + suffix))
	print("v81_goal_save checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
