extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 abyss save: " + label)

func _init() -> void:
	var old: Dictionary = {"save_version": 33, "weekly_content_key": "2960", "weekly_trial_best": 12000,
		"weekly_trial_runs": 4, "wallet_gold": 987, "wallet_gems": 123,
		"tower_floor": 12, "tower_best_floor": 11, "daily_dungeon_clears": {"aurelia:gold_rush:0": true}}
	var clean: Dictionary = SaveValidation.sanitize(old, ["gray_meadow"])
	_check(clean["weekly_trial_best"] == 0 and clean["weekly_trial_legacy_best"] == 12000 and clean["weekly_trial_legacy_week"] == "2960", "legacy power score archived")
	_check(clean["weekly_trial_runs"] == 4 and clean["wallet_gold"] == 987 and clean["wallet_gems"] == 123, "migration never refills allowance or pays")
	_check(clean["daily_dungeon_clears"] == old["daily_dungeon_clears"] and clean["tower_floor"] == 12, "daily and tower preserved")
	_check(clean["weekly_trial_score_version"] == 1, "new score semantics marked")
	clean["weekly_trial_best"] = 3456
	var clean_again: Dictionary = SaveValidation.sanitize(clean, ["gray_meadow"])
	_check(clean_again["weekly_trial_best"] == 3456 and clean_again["weekly_trial_legacy_best"] == 12000, "migration idempotent")
	for invalid in [null, {}, [], "bad", -1, 1e300]:
		var malformed: Dictionary = SaveValidation.sanitize({"weekly_trial_score_version": 1,
			"weekly_trial_best": invalid, "weekly_trial_legacy_best": invalid}, ["gray_meadow"])
		_check(int(malformed["weekly_trial_best"]) >= 0 and int(malformed["weekly_trial_best"]) <= SaveValidation.MAX_CURRENCY, "score input bounded")
	var path: String = "user://v80-4-weekly-save-%d.json" % OS.get_process_id()
	var store := SaveStore.new()
	_check(store.write_save(path, clean_again).get("ok", false), "real save write")
	var loaded: Dictionary = store.read_save(path)
	_check(loaded.get("ok", false), "real save read")
	if loaded.get("ok", false):
		var roundtrip: Dictionary = SaveValidation.sanitize(loaded["data"], ["gray_meadow"])
		_check(roundtrip["weekly_trial_best"] == 3456 and roundtrip["weekly_trial_runs"] == 4 and roundtrip["weekly_trial_legacy_best"] == 12000, "new score and old archive survive reload")
	_check(SaveStore.VERSION >= 34, "schema protects new semantics from old client")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("v80_abyss_save checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
