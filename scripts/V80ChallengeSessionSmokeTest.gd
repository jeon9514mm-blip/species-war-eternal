extends SceneTree

const SESSION = preload("res://scripts/ChallengeBattleSession.gd")
const DAILY = preload("res://scripts/DailyDungeonBattleRules.gd")
var failures: Array[String] = []
var checks: int = 0

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _init() -> void:
	var invalid: ChallengeBattleSession = SESSION.new()
	_check(not invalid.begin(1, {"limit_seconds": -1, "required_waves": 3}, {}), "negative duration rejected")
	_check(not invalid.begin(0, DAILY.plan(), {}), "invalid serial rejected")
	var session: ChallengeBattleSession = SESSION.new()
	var entry: Dictionary = {"run_index": 0, "day": "2026-09-30"}
	_check(session.begin(11, DAILY.plan(), entry), "session starts")
	entry["run_index"] = 2
	_check(int(session.entry_context["run_index"]) == 0, "entry context copied")
	_check(not session.begin(12, DAILY.plan(), {}), "cannot start twice")
	_check(session.take_victory_receipt(11).is_empty(), "entry has no receipt")
	_check(not session.complete_wave(-1, 0, 10), "empty encounter cannot clear")
	for wave in 3:
		var token: int = wave + 101
		_check(session.start_wave(token), "wave starts")
		_check(not session.start_wave(token + 10), "cannot start overlapping waves")
		_check(not session.complete_wave(token, 1, 10), "living enemy blocks clear")
		_check(not session.complete_wave(token, 0, 0), "dead party blocks clear")
		_check(not session.complete_wave(token + 1, 0, 10), "stale token rejected")
		_check(session.complete_wave(token, 0, 10), "real cleared wave accepted")
		_check(not session.complete_wave(token, 0, 10), "duplicate wave cannot count twice")
	_check(session.state == SESSION.State.WON, "three cleared waves win")
	_check(session.take_victory_receipt(99).is_empty(), "wrong serial cannot settle")
	_check(not session.take_victory_receipt(11).is_empty(), "winner settles once")
	_check(session.take_victory_receipt(11).is_empty(), "duplicate payout denied")
	var timeout: ChallengeBattleSession = SESSION.new()
	timeout.begin(12, DAILY.plan(), {})
	timeout.advance_clock(-1.0)
	timeout.advance_clock(NAN)
	_check(timeout.elapsed == 0.0, "negative and nonfinite deltas ignored")
	timeout.advance_clock(59.0)
	_check(timeout.is_running(), "still active before deadline")
	timeout.advance_clock(1.0)
	_check(timeout.state == SESSION.State.LOST and timeout.reason == "timeout", "deadline causes defeat")
	_check(timeout.take_victory_receipt(12).is_empty(), "timeout cannot pay")
	var cancelled: ChallengeBattleSession = SESSION.new()
	cancelled.begin(13, DAILY.plan(), {})
	cancelled.cancel()
	_check(not cancelled.start_wave(1) and cancelled.take_victory_receipt(13).is_empty(), "cancelled session inert")
	var defeated: ChallengeBattleSession = SESSION.new()
	defeated.begin(14, DAILY.plan(), {})
	defeated.defeat()
	_check(defeated.state == SESSION.State.LOST, "party defeat is terminal")
	for index in 3:
		var reward: Dictionary = DAILY.reward(index)
		_check(int(reward["gold"]) == 950 + index * 250, "v79 gold formula preserved")
		_check(int(reward["xp"]) == 350 + index * 100, "v79 XP formula preserved")
	_check(DAILY.reward(-1).is_empty() and DAILY.reward(3).is_empty(), "out of quota reward rejected")
	if failures.is_empty():
		print("v80_challenge_session_smoke_test_ok checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
