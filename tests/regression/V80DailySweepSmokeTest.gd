extends SceneTree

const DIRECTOR = preload("res://scripts/combat/ChallengeBattleDirector.gd")
const RULES = preload("res://scripts/progression/DailyDungeonBattleRules.gd")
const PROGRESS = preload("res://scripts/progression/DailyDungeonProgress.gd")
const SESSION = preload("res://scripts/combat/ChallengeBattleSession.gd")

## Settlement unit test host, NOT a simulation of real combat. Real AI is
## exercised separately by V80DailyModesBattleSmokeTest.gd.
class TestHost:
	extends Node
	var daily_dungeon_day: String = "2026-10-01"
	var today: String = "2026-10-01"
	var daily_dungeon_runs: int = 0
	var daily_dungeon_clears: Dictionary = {}
	var selected_faction: String = "aurelia"
	var current_zone_id: String = "gray_meadow"
	var deployed_heroes: Array = [{"id": "leonhardt"}]
	var wallet_gold: int = 0
	var wallet_xp: int = 0
	var hero_xp: int = 0
	var pet_xp: int = 0
	var combat_running: bool = false
	var _save_blocked_for_newer_version: bool = false
	var challenge_session: ChallengeBattleSession = null
	var snapshots: Array = []
	func _today_key() -> String:
		return today
	func _deployed_hero_ids() -> Array:
		var ids: Array = []
		for hero in deployed_heroes:
			ids.append(hero["id"])
		return ids
	func _grant_hero_xp(amount: int) -> void:
		hero_xp += amount
	func _grant_pet_xp(amount: int) -> void:
		pet_xp += amount
	func _show_toast(_message: String) -> void:
		pass
	func _build_meta_hub_screen() -> void:
		pass
	func _save_idle_state() -> void:
		snapshots.append({"daily_dungeon_clears": daily_dungeon_clears.duplicate(true), "daily_dungeon_runs": daily_dungeon_runs, "wallet_gold": wallet_gold, "wallet_xp": wallet_xp})

var checks: int = 0
var failures: Array[String] = []

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _winner(host: TestHost, variant: String = "gold_rush") -> ChallengeBattleSession:
	var session: ChallengeBattleSession = SESSION.new()
	session.begin(42, RULES.plan(variant), DIRECTOR.entry_context(host))
	for wave in 3:
		if not session.is_running():
			break
		session.start_wave(wave + 1)
		session.complete_wave(wave + 1, 0, 1)
	if variant == "survival":
		session.advance_clock(60.0, 1)
	host.challenge_session = session
	return session

func _init() -> void:
	var host: TestHost = TestHost.new()
	var locked_context: Dictionary = DIRECTOR.entry_context(host)
	_check(not DIRECTOR.sweep_daily(host, "gold_rush", locked_context), "sweep before direct clear blocked")
	_check(host.wallet_gold == 0 and host.daily_dungeon_runs == 0, "locked sweep has no costs or rewards")
	for tier in 3:
		PROGRESS.record_direct_clear(host.daily_dungeon_clears, "aurelia", "gold_rush", tier)
	var ledger_before: Dictionary = host.daily_dungeon_clears.duplicate(true)
	var first_context: Dictionary = DIRECTOR.entry_context(host)
	_check(DIRECTOR.sweep_daily(host, "gold_rush", first_context), "unlocked sweep succeeds")
	_check(host.wallet_gold == 950 and host.wallet_xp == 350 and host.hero_xp == 350 and host.pet_xp == 60, "exact single-run payout")
	_check(host.daily_dungeon_runs == 1 and host.snapshots.size() == 1, "one completion with one save snapshot")
	_check(host.snapshots[0]["daily_dungeon_runs"] == 1 and host.snapshots[0]["wallet_gold"] == 950, "quota and wallet saved together")
	_check(not DIRECTOR.sweep_daily(host, "gold_rush", first_context), "duplicate click cannot consume next unlocked tier")
	_check(host.daily_dungeon_runs == 1 and host.wallet_gold == 950, "duplicate has zero side effects")
	_check(host.daily_dungeon_clears == ledger_before, "sweeping does not manufacture clear records")
	_check(not DIRECTOR.sweep_daily(host, "survival", DIRECTOR.entry_context(host)), "switching modes does not share unlocks")
	for tier in [1, 2]:
		_check(DIRECTOR.sweep_daily(host, "gold_rush", DIRECTOR.entry_context(host)), "fresh UI request uses next cleared tier")
	_check(host.daily_dungeon_runs == 3 and host.wallet_gold == 3600 and host.wallet_xp == 1350, "original total daily rewards")
	_check(not DIRECTOR.sweep_daily(host, "gold_rush", DIRECTOR.entry_context(host)), "shared daily cap enforced")
	host.free()
	for mutation in ["day", "faction", "party", "quota", "newer_save"]:
		var changed: TestHost = TestHost.new()
		_winner(changed)
		match mutation:
			"day": changed.today = "2026-10-02"
			"faction": changed.selected_faction = "noxfera"
			"party": changed.deployed_heroes = [{"id": "mira"}]
			"quota": changed.daily_dungeon_runs = 1
			"newer_save": changed._save_blocked_for_newer_version = true
		DIRECTOR.finish(changed)
		_check(changed.wallet_gold == 0 and changed.daily_dungeon_clears.is_empty(), "changed " + mutation + " blocks payout/unlock")
		changed.free()
	for variant in RULES.VARIANTS:
		var victor: TestHost = TestHost.new()
		_winner(victor, variant)
		DIRECTOR.finish(victor)
		_check(victor.wallet_gold == 950 and victor.daily_dungeon_runs == 1, variant + " settled once")
		_check(PROGRESS.can_sweep(victor.daily_dungeon_clears, "aurelia", variant, 0), variant + " direct victory unlock")
		DIRECTOR.finish(victor)
		_check(victor.wallet_gold == 950, "late duplicate finish harmless")
		victor.free()
	for cause in ["timeout", "party_defeated", "cancelled"]:
		var loser: TestHost = TestHost.new()
		var session: ChallengeBattleSession = SESSION.new()
		session.begin(43, RULES.plan(), DIRECTOR.entry_context(loser))
		if cause == "cancelled": session.cancel()
		else: session.defeat(cause)
		loser.challenge_session = session
		DIRECTOR.finish(loser)
		_check(loser.wallet_gold == 0 and loser.daily_dungeon_runs == 0 and loser.daily_dungeon_clears.is_empty(), cause + " cannot pay or unlock")
		loser.free()
	var save_path: String = "user://v80-2-sweep-%d.json" % OS.get_process_id()
	var store := SaveStore.new()
	var clear_data: Dictionary = {"daily_dungeon_clears": {"aurelia:survival:0": true}, "daily_dungeon_runs": 1, "wallet_gold": 950}
	_check(bool(store.write_save(save_path, clear_data).get("ok", false)), "clear record saved to actual JSON")
	var loaded: Dictionary = store.read_save(save_path)
	_check(bool(loaded.get("ok", false)), "saved record read")
	if loaded.get("ok", false):
		var clean: Dictionary = SaveValidation.sanitize(loaded["data"], ["gray_meadow"])
		_check(PROGRESS.can_sweep(clean["daily_dungeon_clears"], "aurelia", "survival", 0), "clear survives save/load/sanitize")
		_check(int(clean["daily_dungeon_runs"]) == 1 and int(clean["wallet_gold"]) == 950, "quota and wallet round-trip together")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("v80_daily_sweep_unit checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
