extends SceneTree

const RULES = preload("res://scripts/TowerBattleRules.gd")
const SESSION = preload("res://scripts/ChallengeBattleSession.gd")
const ECOLOGY = preload("res://scripts/FieldEcology.gd")
var checks: int = 0
var failures: Array[String] = []

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V80 tower rules: " + label)

func _init() -> void:
	_check(RULES.MAX_CLEAR_FLOOR + 1 == SaveValidation.MAX_STAGE, "last reward leaves a persistable next-floor sentinel")
	for invalid_floor in [-5, 0, 10000, 999999]:
		_check(RULES.plan(invalid_floor).is_empty() and RULES.reward(invalid_floor).is_empty(), "invalid floor has no encounter or reward")
		_check(RULES.wave_names(invalid_floor, 0).is_empty(), "invalid floor has no enemies")
	for floor_number in [1, 2, 3, 4, 5, 6, 10, 99, 100, 9999]:
		var plan: Dictionary = RULES.plan(floor_number)
		var boss_floor: bool = floor_number % 5 == 0
		var expected_waves: int = 3 if boss_floor else 2
		_check(plan["mode"] == "tower" and plan["objective"] == "waves", "tower uses real wave objective")
		_check(int(plan["required_waves"]) == expected_waves and float(plan["limit_seconds"]) == 90.0, "floor contract")
		var reward: Dictionary = RULES.reward(floor_number)
		_check(reward == {"gold": 250 + floor_number * 90, "gems": 2 + int(floor_number / 5.0)}, "v79 gold and integer-gem rewards unchanged")
		var session: ChallengeBattleSession = SESSION.new()
		_check(session.begin(floor_number, plan, {"floor": floor_number}), "session created")
		_check(session.take_victory_receipt(floor_number).is_empty(), "entry cannot grant a receipt")
		var bosses: int = 0
		for wave in expected_waves:
			var names: Array = RULES.wave_names(floor_number, wave)
			_check(names.size() == (3 if wave == 2 else 4), "bounded enemy population")
			for index in names.size():
				var stats: Dictionary = RULES.enemy_stats(floor_number, wave, index)
				_check(ECOLOGY.SPECIES.has(stats["name"]), "uses existing species and art lookup names")
				_check(int(stats["hp"]) > 0 and int(stats["attack"]) > 0, "positive finite enemy stats")
				if bool(stats["boss"]): bosses += 1
			_check(session.start_wave(wave + 1), "one active wave")
			_check(not session.complete_wave(wave + 1, 1, 1), "living enemy blocks completion")
			_check(not session.complete_wave(wave + 1, 0, 0), "dead party cannot win")
			_check(session.complete_wave(wave + 1, 0, 1), "observed clear credited")
			_check(not session.complete_wave(wave + 1, 0, 1), "duplicate wave not credited")
			if wave < expected_waves - 1:
				_check(session.is_running(), "all waves required")
		_check(bosses == (1 if boss_floor else 0), "single boss only on every fifth floor")
		_check(RULES.wave_names(floor_number, expected_waves).is_empty(), "cannot spawn an extra reward wave")
		_check(session.state == SESSION.State.WON, "last actual wave wins")
		_check(session.take_victory_receipt(floor_number + 1).is_empty(), "wrong serial rejected")
		_check(not session.take_victory_receipt(floor_number).is_empty(), "one settlement receipt")
		_check(session.take_victory_receipt(floor_number).is_empty(), "receipt consumed once")
	var timeout: ChallengeBattleSession = SESSION.new()
	timeout.begin(700, RULES.plan(1), {})
	timeout.start_wave(1)
	timeout.advance_clock(NAN, 1)
	timeout.advance_clock(-1.0, 1)
	_check(timeout.elapsed == 0.0, "invalid time ignored")
	timeout.advance_clock(90.0, 1)
	_check(timeout.state == SESSION.State.LOST, "surviving alone does not clear tower")
	_check(not timeout.complete_wave(1, 0, 1), "late kill after timeout rejected")
	print("v80_tower_rules checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
