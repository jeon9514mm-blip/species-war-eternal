extends SceneTree

const RULES = preload("res://scripts/TowerBattleRules.gd")
const PROGRESS = preload("res://scripts/TowerProgressionService.gd")
const DRIVER = preload("res://scripts/ChallengeBattleDirector.gd")
const SESSION = preload("res://scripts/ChallengeBattleSession.gd")

## UNIT host: deliberately reports wave observations. It is NOT a real-combat
## test and must not be counted as evidence that the game's AI can clear floors.
class TestHost:
	extends Node
	var last_save_status: String = "saved"
	var tower_floor: int = 1
	var tower_best_floor: int = 0
	var challenge_serial: int = 700
	var challenge_session: ChallengeBattleSession = null
	var selected_faction: String = "aurelia"
	var current_zone_id: String = "gray_meadow"
	var deployed_heroes: Array = [{"id": "leonhardt"}]
	var wallet_gold: int = 100
	var wallet_gems: int = 10
	var wallet_xp: int = 40
	var daily_dungeon_runs: int = 2
	var daily_dungeon_clears: Dictionary = {"aurelia:survival:0": true}
	var weekly_trial_runs: int = 3
	var combat_running: bool = true
	var _save_blocked_for_newer_version: bool = false
	var snapshots: Array = []
	func _deployed_hero_ids() -> Array:
		var ids: Array = []
		for hero in deployed_heroes: ids.append(hero["id"])
		return ids
	func _show_toast(_message: String) -> void:
		pass
	func _build_meta_hub_screen() -> void:
		pass
	func _save_idle_state() -> void:
		snapshots.append({"tower_floor": tower_floor, "tower_best_floor": tower_best_floor,
			"wallet_gold": wallet_gold, "wallet_gems": wallet_gems, "wallet_xp": wallet_xp,
			"daily_dungeon_runs": daily_dungeon_runs, "daily_dungeon_clears": daily_dungeon_clears.duplicate(true)})

var checks: int = 0
var failures: Array[String] = []

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 tower settlement: " + label)

func _session(host: TestHost, win: bool = true) -> ChallengeBattleSession:
	var session: ChallengeBattleSession = SESSION.new()
	session.begin(host.challenge_serial, RULES.plan(host.tower_floor), PROGRESS.entry_context(host))
	host.challenge_session = session
	if win:
		for wave in session.required_waves:
			session.start_wave(wave + 1)
			session.complete_wave(wave + 1, 0, 1)
	return session

func _init() -> void:
	for floor_number in [1, 5, 9999]:
		var host: TestHost = TestHost.new()
		host.tower_floor = floor_number
		host.tower_best_floor = floor_number - 1
		var original_context: Dictionary = PROGRESS.entry_context(host)
		_check(PROGRESS.entry_error(host).is_empty(), "entry has no party-power gate")
		var session: ChallengeBattleSession = _session(host)
		DRIVER.finish(host)
		var reward: Dictionary = RULES.reward(floor_number)
		_check(host.tower_floor == floor_number + 1 and host.tower_best_floor == floor_number, "floor increments once after victory")
		_check(host.wallet_gold == 100 + int(reward["gold"]) and host.wallet_gems == 10 + int(reward["gems"]), "exact old reward")
		_check(host.daily_dungeon_runs == 2 and host.weekly_trial_runs == 3 and host.wallet_xp == 40, "no daily/weekly quota or XP leakage")
		_check(host.daily_dungeon_clears == {"aurelia:survival:0": true}, "daily sweep unlocks unchanged")
		_check(host.challenge_session == null and host.snapshots.size() == 1, "one detached settlement save")
		_check(not PROGRESS.context_matches(host, original_context), "old UI context no longer matches next floor")
		DRIVER.finish(host)
		PROGRESS.finish(host, session)
		_check(host.snapshots.size() == 1 and host.wallet_gold == 100 + int(reward["gold"]), "duplicate callbacks harmless")
		var clean: Dictionary = SaveValidation.sanitize(host.snapshots[0], ["gray_meadow"])
		_check(int(clean["tower_floor"]) == host.tower_floor and int(clean["tower_best_floor"]) == host.tower_best_floor, "progress remains valid after save sanitization")
		if floor_number == RULES.MAX_CLEAR_FLOOR:
			_check(not PROGRESS.entry_error(host).is_empty(), "persisted end sentinel cannot pay repeatedly")
		host.free()
	for mutation in ["floor", "best", "faction", "zone", "party", "serial", "newer_save"]:
		var host: TestHost = TestHost.new()
		_session(host)
		match mutation:
			"floor": host.tower_floor = 2
			"best": host.tower_best_floor = 1
			"faction": host.selected_faction = "noxfera"
			"zone": host.current_zone_id = "forgotten_mine"
			"party": host.deployed_heroes = [{"id": "mira"}]
			"serial": host.challenge_serial += 1
			"newer_save": host._save_blocked_for_newer_version = true
		var before: Array = [host.tower_floor, host.tower_best_floor, host.wallet_gold, host.wallet_gems]
		DRIVER.finish(host)
		_check(before == [host.tower_floor, host.tower_best_floor, host.wallet_gold, host.wallet_gems], "changed " + mutation + " blocks settlement")
		_check(not bool(host.get_meta("last_dungeon_result").get("settled", true)), "rejected result is not labeled as paid")
		host.free()
	for cause in ["timeout", "party_defeated", "cancel", "invalid_wave"]:
		var host: TestHost = TestHost.new()
		var session: ChallengeBattleSession = _session(host, false)
		if cause == "cancel": session.cancel()
		else: session.defeat(cause)
		DRIVER.finish(host)
		_check(host.tower_floor == 1 and host.tower_best_floor == 0 and host.wallet_gold == 100 and host.wallet_gems == 10, cause + " leaves progress and rewards unchanged")
		host.free()
	var active_host: TestHost = TestHost.new()
	var old_session: ChallengeBattleSession = _session(active_host)
	active_host.challenge_serial += 1
	var active: ChallengeBattleSession = _session(active_host, false)
	PROGRESS.finish(active_host, old_session)
	DRIVER.finish(active_host)
	_check(active_host.challenge_session == active and active_host.wallet_gold == 100, "stale finished session cannot settle or detach a new running session")
	active_host.free()
	# Actual SaveStore round-trip when this script runs in Godot (not yet run
	# merely because the file exists).
	var path: String = "user://v80-3-tower-%d.json" % OS.get_process_id()
	var store := SaveStore.new()
	var saved: Dictionary = {"tower_floor": 43, "tower_best_floor": 42, "wallet_gold": 1200, "wallet_gems": 20}
	_check(bool(store.write_save(path, saved).get("ok", false)), "write tower snapshot")
	var loaded: Dictionary = store.read_save(path)
	_check(bool(loaded.get("ok", false)), "read tower snapshot")
	if loaded.get("ok", false):
		var clean: Dictionary = SaveValidation.sanitize(loaded["data"], ["gray_meadow"])
		_check(clean["tower_floor"] == 43 and clean["tower_best_floor"] == 42, "legacy tower progress is not reset")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("v80_tower_settlement checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
