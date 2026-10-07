extends SceneTree

const RULES = preload("res://scripts/progression/WeeklyAbyssBattleRules.gd")
const SERVICE = preload("res://scripts/progression/WeeklyAbyssProgressionService.gd")
const DRIVER = preload("res://scripts/combat/ChallengeBattleDirector.gd")
const SESSION = preload("res://scripts/combat/ChallengeBattleSession.gd")
# This UNIT host supplies combat observations. NOT an actual AI battle test.
class Host:
	extends Node
	var last_save_status: String = "saved"
	var weekly_content_key: String = "2960"
	var current_week: String = "2960"
	var weekly_trial_runs: int = 0
	var weekly_trial_best: int = 0
	var selected_faction: String = "aurelia"
	var current_zone_id: String = "gray_meadow"
	var deployed_heroes: Array = [{"id": "leonhardt"}]
	var challenge_serial: int = 42
	var challenge_session: ChallengeBattleSession = null
	var _save_blocked_for_newer_version: bool = false
	var combat_running: bool = true
	var wallet_gold: int = 100
	var wallet_gems: int = 10
	var hero_xp: int = 0
	var daily_dungeon_runs: int = 2
	var tower_floor: int = 5
	var saves: Array = []
	func _week_key() -> String: return current_week
	func _deployed_hero_ids() -> Array:
		var ids: Array = []
		for hero in deployed_heroes: ids.append(hero["id"])
		return ids
	func _grant_hero_xp(amount: int) -> void: hero_xp += amount
	func _build_meta_hub_screen() -> void: pass
	func _show_toast(_text: String) -> void: pass
	func _save_idle_state() -> void:
		saves.append([weekly_trial_runs, weekly_trial_best, wallet_gold, wallet_gems, hero_xp])

var checks: int = 0
var failures: Array[String] = []
func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 abyss settlement: " + label)

func _session(host: Host, complete: bool = true) -> ChallengeBattleSession:
	var session: ChallengeBattleSession = SESSION.new()
	session.begin(host.challenge_serial, RULES.plan(host.weekly_content_key), SERVICE.entry_context(host))
	host.challenge_session = session
	session.start_wave(10)
	session.register_score_target(10, "unit-observation", 1000)
	session.record_hp_loss(10, "unit-observation", 1000, 750)
	if complete: session.advance_clock(90.0, 1)
	return session

func _init() -> void:
	for run_index in 5:
		var host: Host = Host.new()
		host.weekly_trial_runs = run_index
		host.weekly_trial_best = 400 if run_index % 2 == 0 else 100
		var prior_best: int = host.weekly_trial_best
		var entry: Dictionary = SERVICE.entry_context(host)
		_check(SERVICE.entry_error(host).is_empty(), "entry independent of power")
		var session: ChallengeBattleSession = _session(host)
		DRIVER.finish(host)
		var reward: Dictionary = RULES.reward(run_index)
		_check(host.weekly_trial_runs == run_index + 1 and host.weekly_trial_best == maxi(prior_best, 250), "quota and highest actual score once")
		_check(host.wallet_gold == 100 + int(reward["gold"]) and host.wallet_gems == 10 + int(reward["gems"]) and host.hero_xp == int(reward["hero_xp"]), "exact existing reward")
		_check(host.daily_dungeon_runs == 2 and host.tower_floor == 5, "other contents untouched")
		_check(host.challenge_session == null and host.saves.size() == 1, "detached and saved together")
		_check(not SERVICE.context_matches(host, entry), "stale button cannot start next attempt")
		SERVICE.finish(host, session)
		DRIVER.finish(host)
		_check(host.saves.size() == 1, "duplicate settlement ignored")
		host.free()
	for change in ["week", "period", "run", "best", "faction", "zone", "party", "serial", "protected"]:
		var host: Host = Host.new()
		_session(host)
		match change:
			"week": host.current_week = "2961"
			"period": host.weekly_content_key = "2961"
			"run": host.weekly_trial_runs = 1
			"best": host.weekly_trial_best = 999
			"faction": host.selected_faction = "noxfera"
			"zone": host.current_zone_id = "forgotten_mine"
			"party": host.deployed_heroes = [{"id": "mira"}]
			"serial": host.challenge_serial += 1
			"protected": host._save_blocked_for_newer_version = true
		var before: Array = [host.weekly_trial_runs, host.weekly_trial_best, host.wallet_gold, host.wallet_gems]
		DRIVER.finish(host)
		_check(before == [host.weekly_trial_runs, host.weekly_trial_best, host.wallet_gold, host.wallet_gems], change + " cancels payout")
		_check(not bool(host.get_meta("last_dungeon_result").get("settled", true)), "invalid is not labeled paid")
		host.free()
	for reason in ["party_defeated", "invalid_wave", "cancel"]:
		var host: Host = Host.new()
		var session: ChallengeBattleSession = _session(host, false)
		if reason == "cancel": session.cancel()
		else: session.defeat(reason)
		DRIVER.finish(host)
		_check(host.weekly_trial_runs == 0 and host.weekly_trial_best == 0 and host.wallet_gold == 100, "failure/cancel preserves allowance and score")
		host.free()
	var busy: Host = Host.new()
	var old: ChallengeBattleSession = _session(busy)
	busy.challenge_serial += 1
	var current: ChallengeBattleSession = _session(busy, false)
	SERVICE.finish(busy, old)
	_check(busy.challenge_session == current and busy.wallet_gold == 100, "old callback cannot detach new run")
	busy.free()
	print("v80_abyss_settlement checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
