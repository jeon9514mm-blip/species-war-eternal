extends SceneTree

const VARIETY = preload("res://scripts/hunting/FieldHuntVariety.gd")

var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _init() -> void:
	var early: Dictionary = VARIETY.encounter_profile(1, 1, 1, "gray_meadow")
	_check(str(early.get("type", "")) == VARIETY.EVENT_STANDARD, "stage 1 keeps the original standard hunt")
	_check(is_equal_approx(VARIETY.combo_bonus(1), 0.0), "first clear has no combo reward bonus")
	_check(is_equal_approx(VARIETY.combo_bonus(11), 0.25), "combo reward bonus reaches the +25% cap")
	_check(is_equal_approx(VARIETY.combo_bonus(99), 0.25), "combo reward bonus never exceeds +25%")
	_check(VARIETY.combo_window(1) > VARIETY.combo_window(3), "harder zones use a slightly tighter combo window")

	var seen: Dictionary = {}
	for encounter in range(1, 500):
		var profile: Dictionary = VARIETY.encounter_profile(encounter, 12, 3, "moonrest_forest")
		var event_type := str(profile.get("type", ""))
		seen[event_type] = true
		_check(event_type in [VARIETY.EVENT_STANDARD, VARIETY.EVENT_ELITE, VARIETY.EVENT_TREASURE, VARIETY.EVENT_AMBUSH, VARIETY.EVENT_LUCKY], "encounter profile only returns supported events")
		_check(float(profile.get("reward_mult", 0.0)) >= 1.0, "event reward multiplier never penalizes a clear")
	_check(seen.has(VARIETY.EVENT_ELITE), "deterministic encounter rotation can produce elite patrols")
	_check(seen.has(VARIETY.EVENT_TREASURE), "deterministic encounter rotation can produce treasure hunts")
	_check(seen.has(VARIETY.EVENT_AMBUSH), "deterministic encounter rotation can produce ambushes")
	_check(seen.has(VARIETY.EVENT_LUCKY), "deterministic encounter rotation can produce lucky finds")

	var elite := {"hp":100, "max_hp":100, "attack":20, "base_attack":20, "sight_radius":2.0, "leash_radius":2.8}
	VARIETY.apply_elite_affix(elite, "ironhide")
	_check(int(elite["max_hp"]) > 100 and int(elite["attack"]) >= 20, "ironhide increases elite durability without lowering attack")
	_check(int(elite["hp"]) == int(elite["max_hp"]) and int(elite["base_attack"]) == int(elite["attack"]), "elite affix updates reset baselines")

	var keen := {"hp":100, "max_hp":100, "attack":20, "base_attack":20, "sight_radius":2.0, "leash_radius":2.8}
	VARIETY.apply_elite_affix(keen, "keen")
	_check(float(keen["sight_radius"]) > 2.0 and float(keen["leash_radius"]) > 2.8, "keen elite gains detection and chase pressure")

	if failures.is_empty():
		print("v77_hunt_variety_smoke_test_ok events=ok elite_affixes=ok combo_cap=ok")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
