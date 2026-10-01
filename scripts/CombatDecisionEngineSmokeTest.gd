extends SceneTree

const EngineScript = preload("res://scripts/CombatDecisionEngine.gd")

var checks := 0
var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("CombatDecisionEngine: " + message)

func _hero(role := "딜러", attack_range := 3, style := "balanced", row := "front") -> Dictionary:
	return {"hp": 100, "max_hp": 100, "role_group": role, "range": attack_range, "ai_style": style, "row": row, "alive": true}

func _enemy(hp := 100, row := 0, attack := 20, archetype := "brute", elite := false) -> Dictionary:
	return {"hp": hp, "max_hp": 100, "row": row, "attack": attack, "archetype": archetype, "elite": elite}

func _init() -> void:
	var engine = EngineScript.new()
	var hero := _hero()
	_check(engine.select_enemy_target(hero, []) == -1, "empty wave must have no target")
	_check(engine.select_enemy_target({}, [_enemy()]) == -1, "missing attacker must not acquire a target")
	var dead_hero := _hero()
	dead_hero["hp"] = 0
	_check(not engine.can_attack_enemy(dead_hero, [_enemy()], 0), "dead attacker must not attack")
	var invalid_wave: Array = [null, "invalid", {}, _enemy(0), _enemy(10)]
	_check(engine.select_enemy_target(hero, invalid_wave) == 4, "ignore malformed or dead enemies")
	invalid_wave[4]["alive"] = false
	_check(engine.select_enemy_target(hero, invalid_wave) == -1, "explicit defeated flag must exclude target")
	_check(not engine.can_attack_enemy(hero, [_enemy()], -1), "negative target index must be rejected")
	_check(not engine.can_attack_enemy(hero, [_enemy()], 1), "missing target index must be rejected")

	var wave := [_enemy(), _enemy(100, 1, 30, "support", true), _enemy(1, 2)]
	var melee := _hero("딜러", 1)
	var middle := _hero("딜러", 2)
	_check(engine.select_enemy_target(melee, wave) == 0, "melee must respect front row in row-only mode")
	_check(engine.select_enemy_target(middle, wave) == 1, "range two must prioritize reachable elite support and exclude row two")
	_check(engine.select_enemy_target(hero, wave) == 2, "range three may finish a rear target")
	wave[0]["hp"] = 0
	_check(engine.select_enemy_target(melee, wave) == 1, "melee must advance once front row dies")

	var spatial_wave := [_enemy(), _enemy(100, 1)]
	_check(engine.select_enemy_target(melee, spatial_wave, [3.0, 0.8]) == 1, "distant front row must not block a nearby rear enemy")
	_check(engine.can_attack_enemy(melee, spatial_wave, 1, [3.0, 0.8]), "execution validation must agree for nearby rear enemy")
	_check(engine.can_attack_enemy(melee, spatial_wave, 1, [0.9, 0.8]), "physical reach ignores formation row tags in free-field combat")
	_check(engine.select_enemy_target(melee, spatial_wave, [2.0, 2.1], 0) == -1, "out-of-range previous target must be released")
	_check(engine.select_enemy_target(melee, spatial_wave, [NAN, INF]) == -1, "non-finite distances must be rejected")
	_check(engine.select_enemy_target(melee, spatial_wave, [-0.1, "near"]) == -1, "negative and malformed distances must be rejected")
	_check(not engine.can_attack_enemy(melee, spatial_wave, 1, [0.8]), "missing spatial distance must not silently allow an attack")
	for attack_range in [1, 2, 3]:
		var ranged_hero := _hero("딜러", attack_range)
		var limit: float = engine.spatial_range(attack_range)
		_check(engine.can_attack_enemy(ranged_hero, [_enemy()], 0, [limit]), "attack must work at range boundary %d" % attack_range)
		_check(not engine.can_attack_enemy(ranged_hero, [_enemy()], 0, [limit + 0.001]), "attack must fail outside range boundary %d" % attack_range)

	var equal_targets := [_enemy(), _enemy()]
	_check(engine.select_enemy_target(hero, equal_targets) == 0, "selection must have a deterministic initial tie break")
	_check(engine.select_enemy_target(hero, equal_targets, [], 1) == 1, "equivalent valid target must be retained")
	equal_targets[0]["hp"] = 97
	_check(engine.select_enemy_target(hero, equal_targets, [], 1) == 1, "minor HP change must not cause target jitter")
	equal_targets[0]["hp"] = 40
	_check(engine.select_enemy_target(hero, equal_targets, [], 1) == 0, "clear finishing opportunity must override target retention")
	equal_targets[0]["hp"] = 0
	_check(engine.select_enemy_target(hero, equal_targets, [], 0) == 1, "dead previous target must immediately retarget")

	var priority_wave := [_enemy(), _enemy(100, 1, 30, "support", true)]
	_check(engine.select_enemy_target(_hero("딜러", 2, "finisher"), priority_wave) == 1, "V18 Mira elite support priority must be preserved")
	var finish_wave := [_enemy(60), _enemy(100, 1, 30, "support", true)]
	_check(engine.select_enemy_target(hero, finish_wave) == 1, "balanced attacker baseline should prioritize elite support")
	_check(engine.select_enemy_target(_hero("딜러", 3, "finisher"), finish_wave) == 0, "finisher identity must favor a wounded target more strongly")
	var threat_wave := [_enemy(), _enemy(100, 0, 70, "assassin")]
	_check(engine.select_enemy_target(_hero("탱커", 1, "protector"), threat_wave) == 1, "protector must address the more dangerous reachable attacker")
	_check(engine.select_enemy_target(_hero("컨트롤러", 3, "controller"), [_enemy(20), _enemy(100, 0, 90)]) == 1, "controller must prioritize enemy attack danger")
	_check(engine.select_enemy_target(_hero("서포터", 3, "controller"), [_enemy(20), _enemy(100, 0, 90)]) == 1, "controller identity must apply to support-role debuff heroes")

	var states := {"tank": _hero("탱커"), "front": _hero(), "healer": _hero("서포터", 3, "support", "middle"), "rear": _hero("딜러", 3, "balanced", "rear")}
	var ids := ["tank", "front", "healer", "rear"]
	_check(engine.select_hero_target(_enemy(), 0, states, ids) == "tank", "brute must target a tank")
	_check(engine.select_hero_target(_enemy(100, 0, 20, "assassin"), 0, states, ids) == "healer", "assassin must target support")
	_check(engine.select_hero_target(_enemy(100, 0, 20, "ranged"), 0, states, ids) == "rear", "ranged enemy must target rear")
	states["front"]["taunt"] = 2.0
	_check(engine.select_hero_target(_enemy(100, 0, 20, "assassin"), 0, states, ids, "healer") == "front", "new taunt must immediately override retained support target")
	states["front"]["taunt"] = 0.0
	_check(engine.select_hero_target(_enemy(100, 0, 20, "assassin"), 0, states, ids, "front") == "healer", "expired taunt must restore archetype priority")
	states["healer"]["hp"] = 0
	_check(engine.select_hero_target(_enemy(100, 0, 20, "assassin"), 0, states, ids, "healer") == "rear", "assassin must fall back to rear after support dies")
	states["tank"]["hp"] = 0
	states["tank"]["taunt"] = 10.0
	_check(engine.select_hero_target(_enemy(), 0, states, ids) == "front", "dead taunter must not block front fallback")
	states["rear"]["alive"] = false
	_check(engine.select_hero_target(_enemy(100, 0, 20, "ranged"), 0, states, ids) == "front", "ranged enemy must fall back when rear is defeated")
	_check(engine.select_hero_target(_enemy(), -1, states, ids) == "front", "negative enemy index must safely select a valid target")
	_check(engine.select_hero_target(_enemy(), 0, {"bad": null}, ["missing", "bad"]) == "", "stale or malformed hero IDs must be ignored")
	states["front"]["hp"] = 0
	_check(engine.select_hero_target(_enemy(), 0, states, ids) == "", "party wipe must have no valid target")
	var taunt_states := {"a": _hero("탱커"), "b": _hero("탱커")}
	taunt_states["a"]["taunt"] = 1.0
	taunt_states["b"]["taunt"] = 1.0
	_check(engine.select_hero_target(_enemy(), 1, taunt_states, ["a", "b"]) == "b", "initial taunt targeting must preserve enemy distribution")
	_check(engine.select_hero_target(_enemy(), 0, taunt_states, ["a", "b"], "b") == "b", "valid target should stay stable inside the same priority pool")

	# Fixed seed exercises row, death, distance and retention combinations together.
	var rng := RandomNumberGenerator.new()
	rng.seed = 260922
	for case_index in 160:
		var sample: Array = []
		var distances: Array = []
		for index in 5:
			sample.append(_enemy(rng.randi_range(0, 100), rng.randi_range(0, 2), rng.randi_range(10, 100)))
			distances.append(rng.randf_range(0.2, 2.8))
		var sample_hero := _hero("딜러", rng.randi_range(1, 3))
		var before := sample.duplicate(true)
		var selected: int = engine.select_enemy_target(sample_hero, sample, distances, rng.randi_range(-1, 4))
		var valid_count := 0
		for index in sample.size():
			if engine.can_attack_enemy(sample_hero, sample, index, distances):
				valid_count += 1
		_check((selected == -1 and valid_count == 0) or (selected >= 0 and engine.can_attack_enemy(sample_hero, sample, selected, distances)), "selection/attack agreement case %d" % case_index)
		_check(sample == before, "target decision must not mutate combat state case %d" % case_index)
	if not failures.is_empty():
		print("combat_decision_engine_smoke_test_failed failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
		return
	print("combat_decision_engine_smoke_test_ok checks=%d spatial_rows=ok identity=ok hysteresis=ok taunt=ok seeded_cases=160" % checks)
	quit(0)
