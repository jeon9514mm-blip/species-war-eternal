extends SceneTree

const RULES = preload("res://scripts/progression/WeeklyAbyssBattleRules.gd")
const SESSION = preload("res://scripts/combat/ChallengeBattleSession.gd")
var checks: int = 0
var failures: Array[String] = []

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 abyss rules: " + label)

func _session() -> ChallengeBattleSession:
	var session: ChallengeBattleSession = SESSION.new()
	_check(session.begin(42, RULES.plan("2960"), {}), "valid score plan starts")
	return session

func _init() -> void:
	for week in ["-1", "0", "2960", "999999999999"]:
		var rule: Dictionary = RULES.mutator(week)
		_check(not rule.is_empty(), "valid weekly seed " + week)
		_check(rule["id"] == RULES.mutator(str(int(week) + 3))["id"] if week != "999999999999" else true, "three-week rotation")
		var plan: Dictionary = RULES.plan(week)
		_check(plan["limit_seconds"] == 90.0 and plan["objective"] == "score" and plan["required_waves"] == 0, "score objective has full 90 seconds")
		var stats: Dictionary = RULES.enemy_stats(week, 0)
		_check(stats == RULES.enemy_stats(week, 50), "all bosses same weekly rule")
		_check(int(stats["hp"]) > 0 and int(stats["attack"]) > 0 and float(stats["attack_rate"]) >= 1.0, "positive combat parameters")
	for invalid in ["", "not_a_week", "2.5", "9999999999999"]:
		_check(RULES.plan(invalid).is_empty(), "invalid period rejected")
	for index in 5:
		_check(RULES.reward(index) == {"gold": 1600 + 400 * index, "gems": 18 + 3 * index, "hero_xp": 450 + 100 * index}, "original completion reward")
	_check(RULES.reward(-1).is_empty() and RULES.reward(5).is_empty(), "out of allowance reward rejected")
	var session: ChallengeBattleSession = _session()
	_check(session.start_wave(10) and session.register_score_target(10, "one", 100), "real target registered")
	_check(not session.register_score_target(10, "one", 100), "duplicate registration blocked")
	_check(session.record_hp_loss(10, "one", 100, 60) == 40, "effective loss scored")
	_check(session.record_hp_loss(10, "one", 100, 60) == 0, "duplicate damage callback ignored")
	_check(session.record_hp_loss(10, "unknown", 100, 0) == 0, "unregistered target ignored")
	_check(session.record_hp_loss(9, "one", 60, 0) == 0, "old encounter ignored")
	_check(session.record_hp_loss(10, "one", 60, 90) == 0, "healing not damage")
	_check(session.record_hp_loss(10, "one", 90, 70) == 0, "recovered HP not farmed twice")
	_check(session.record_hp_loss(10, "one", 70, 30) == 30, "only newly depleted HP credited")
	_check(session.record_hp_loss(10, "one", 30, -50) == 0, "negative final HP is invalid")
	_check(session.record_hp_loss(10, "one", 30, 0) == 30 and session.damage_score == 100, "first boss maximum is actual HP")
	_check(session.complete_wave(10, 0, 1) and session.is_running(), "boss death does not end timed run")
	_check(session.start_wave(11) and session.register_score_target(11, "two", 50), "next real boss registered")
	_check(session.record_hp_loss(10, "one", 30, 0) == 0, "old-wave score rejected after respawn")
	session.record_hp_loss(11, "two", 50, 0)
	session.advance_clock(89.9, 1)
	_check(session.is_running(), "no early completion")
	session.advance_clock(0.2, 1)
	_check(session.state == SESSION.State.WON and session.elapsed == 90.0, "alive with damage completes at 90")
	_check(session.record_hp_loss(11, "two", 50, 0) == 0, "late damage ignored")
	_check(session.take_victory_receipt(41).is_empty(), "wrong serial cannot settle")
	_check(int(session.take_victory_receipt(42).get("damage_score", -1)) == 150, "score in actual receipt")
	_check(session.take_victory_receipt(42).is_empty(), "receipt once only")
	for cause in ["blank", "zero_damage", "dead"]:
		var failed: ChallengeBattleSession = _session()
		if cause != "blank":
			failed.start_wave(1)
			failed.register_score_target(1, "boss", 100)
		if cause == "dead": failed.record_hp_loss(1, "boss", 100, 90)
		failed.advance_clock(90.0, 0 if cause == "dead" else 1)
		_check(failed.state == SESSION.State.LOST and failed.take_victory_receipt(42).is_empty(), cause + " cannot earn completion reward")
	var capped: ChallengeBattleSession = _session()
	capped.start_wave(1)
	capped.register_score_target(1, "large", RULES.MAX_SCORE + 100)
	capped.record_hp_loss(1, "large", RULES.MAX_SCORE + 100, 0)
	_check(capped.damage_score == RULES.MAX_SCORE, "score cap avoids save truncation mismatch")
	print("v80_abyss_rules checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
