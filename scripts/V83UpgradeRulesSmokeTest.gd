extends "res://scripts/V83UpgradeTestBase.gd"
const C = preload("res://scripts/LongTermGoalCatalog.gd")
const S = preload("res://scripts/LongTermGoalState.gd")
const M = preload("res://scripts/CombatPresetModel.gd")
const T = preload("res://scripts/TowerBattleRules.gd")
const TS = preload("res://scripts/TowerProgressionService.gd")
const UNIT = preload("res://scripts/V80TowerSettlementSmokeTest.gd")
class FailureHost extends UNIT.TestHost:
	var fail_write: bool = true
	func _save_idle_state() -> void:
		super._save_idle_state()
		last_save_status = "injected_write_failure" if fail_write else "saved"
func _init() -> void:
	for faction in M.FACTIONS:
		var state: Dictionary = S.sanitize({})
		S.advance_periods(state, "2026-10-01", "2960")
		S.observe(state, faction, {"stage": 100, "hero_level": 60, "tower_best": 20}, [])
		S.record(state, faction, "hunt_packs", 1000, "2026-10-01", "2960")
		S.record(state, faction, "daily_clear", 3, "2026-10-01", "2960")
		S.record(state, faction, "tower_clear", 20, "2026-10-01", "2960")
		for i in 20:
			var g: Dictionary = C.guide()[i]
			var context: Dictionary = {"scope":"guide", "faction":faction, "key":""}
			check(S.claim(state, faction, "guide", g.id, context, "2026-10-01", "2960").ok, "first20 guide reachable without fourth daily " + g.id + faction)
			check(not S.claim(state, faction, "guide", g.id, context, "2026-10-01", "2960").ok, "same stable receipt cannot replay " + g.id)
		check(S.sanitize(JSON.parse_string(JSON.stringify(state))) == state, "claimed guide save roundtrip")
	check(C.guide()[8].metric == "challenge_clear" and C.guide()[23].metric == "daily_clear", "early and long-term goal split")
	var record: Dictionary = {"heroes":["leonhardt"], "equipment":{"leonhardt":{"weapon":"w", "armor":"a", "accessory":"r"}}, "guardian":"", "skill_auto":false, "ultimate_auto":true}
	check(not M.sanitize({"aurelia":[record]})["aurelia"][0].is_empty(), "valid preset accepted")
	for invalid in [null, false, 8, "bad", []]: check(M.sanitize(invalid).aurelia == [{},{},{}], "bad root bounded")
	for bad in ["duplicate", "foreign", "shared_item", "missing_slot", "oversize_id"]:
		var copy: Dictionary = record.duplicate(true)
		match bad:
			"duplicate": copy.heroes.append("leonhardt")
			"foreign": copy.heroes[0] = "valeria"
			"shared_item": copy.equipment.leonhardt.armor = "w"
			"missing_slot": copy.equipment.leonhardt.erase("weapon")
			"oversize_id": copy.equipment.leonhardt.weapon = "x".repeat(161)
		check(M.sanitize({"aurelia":[copy]}).aurelia[0].is_empty(), "unsafe preset rejected " + bad)
	var old: Dictionary = SaveValidation.sanitize({"save_version":35,"selected_faction":"aurelia","party_presets":[["leonhardt"],[],[]],"wallet_gold":987,"tower_floor":6,"tower_best_floor":5},["gray_meadow"])
	check(old.combat_presets.aurelia == [{},{},{}] and old.party_presets[0] == ["leonhardt"], "old roster-only preset preserved without fabricated gear records")
	check(old.wallet_gold == 987 and old.tower_floor == 6, "preset migration never changes rewards")
	var host: FailureHost = FailureHost.new()
	var session: ChallengeBattleSession = ChallengeBattleSession.new()
	check(session.begin(host.challenge_serial, T.plan(1), TS.entry_context(host)), "unit session starts")
	host.challenge_session = session
	for wave in session.required_waves:
		session.start_wave(wave + 1); session.complete_wave(wave + 1, 0, 1)
	TS.finish(host, session)
	check(host.wallet_gold == 440 and host.tower_floor == 2, "unit reward applied once before IO fails")
	check(SAFETY.pending(host) and not TS.entry_error(host).is_empty(), "failed tower save blocks next entry")
	TS.finish(host, session)
	check(host.wallet_gold == 440, "same receipt never reapplied")
	host.fail_write = false
	check(SAFETY.retry(host) and not SAFETY.pending(host), "retry clears barrier")
	check(host.wallet_gold == 440 and host.tower_floor == 2 and TS.entry_error(host).is_empty(), "retry writes only snapshot")
	var practice: ChallengeBattleSession = ChallengeBattleSession.new()
	var plan: Dictionary = T.plan(1); plan.practice = true
	practice.begin(800, plan, {})
	for wave in practice.required_waves:
		practice.start_wave(wave+1); practice.complete_wave(wave+1,0,1)
	check(practice.state == ChallengeBattleSession.State.WON and practice.take_victory_receipt(800).is_empty(), "practice cannot mint reward receipt")
	host.free()
	done("v83_upgrade_rules")
