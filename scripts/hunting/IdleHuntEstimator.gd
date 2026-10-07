extends RefCounted
class_name IdleHuntEstimator

const MIN_KILL_INTERVAL := 3.8
const MAX_KILL_INTERVAL := 14.0
const OFFLINE_REWARD_MULTIPLIER := 0.88
const MAX_OFFLINE_STAGE_CLEARS := 5
const MAX_OFFLINE_GEAR_ROLLS := 32
const MAX_ELAPSED_SECONDS := 8 * 60 * 60
const MAX_STAGE := 10000

func _zone_integer(value: Variant, fallback: int, ceiling: int) -> int:
	if typeof(value) == TYPE_INT:
		return clampi(value, 0, ceiling)
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)):
		return int(clampf(float(value), 0.0, float(ceiling)))
	return fallback

func estimate(elapsed_seconds: int, party_power: int, party_size: int, zone: Dictionary, current_stage: int, current_stage_kills: int, stage_target: int, observed: Dictionary = {}) -> Dictionary:
	elapsed_seconds = clampi(elapsed_seconds, 0, MAX_ELAPSED_SECONDS)
	party_size = clampi(party_size, 0, 10)
	var valid_target := stage_target > 0
	stage_target = clampi(stage_target, 1, 1000000)
	current_stage_kills = clampi(current_stage_kills, 0, stage_target - 1)
	current_stage = clampi(current_stage, 1, MAX_STAGE)
	var result := {
		"elapsed": maxi(0, elapsed_seconds),
		"kills": 0,
		"kill_interval": MAX_KILL_INTERVAL,
		"efficiency": 0.0,
		"gold": 0,
		"xp": 0,
		"pet_xp": 0,
		"rations": 0,
		"stage_clears": 0,
		"stage_kills": maxi(0, current_stage_kills),
		"chest_gold": 0,
		"chest_xp": 0,
		"gear_rolls": 0
	}
	if elapsed_seconds <= 0 or party_size <= 0 or not valid_target:
		return result

	var zone_power := float(maxi(1, _zone_integer(zone.get("power", 100), 100, 1000000000)))
	var ratio := maxf(0.05, float(clampi(party_power, 1, 1000000000)) / zone_power)
	var power_efficiency := clampf(pow(ratio, 0.45), 0.42, 1.38)
	var party_efficiency := clampf(0.72 + float(mini(party_size, 10)) * 0.045, 0.76, 1.08)
	var difficulty := maxi(1, _zone_integer(zone.get("difficulty", 1), 1, 3))
	var difficulty_drag := 1.0 + float(difficulty - 1) * 0.05
	var interval := clampf(6.2 * difficulty_drag / (power_efficiency * party_efficiency), MIN_KILL_INTERVAL, MAX_KILL_INTERVAL)
	var observed_interval: Variant = observed.get("seconds_per_pack")
	if typeof(observed_interval) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(observed_interval)):
		# One reward unit is a five-member pack, not one individual monster.
		interval = maxf(interval, clampf(float(observed_interval), 0.1, 3600.0))
	var kills := maxi(0, int(floor(float(elapsed_seconds) / interval)))
	var reward_kills := int(floor(float(kills) * OFFLINE_REWARD_MULTIPLIER))

	result["kills"] = kills
	result["kill_interval"] = interval
	result["efficiency"] = clampf(MIN_KILL_INTERVAL / interval, 0.0, 1.0)
	result["gold"] = reward_kills * _zone_integer(zone.get("gold", 0), 0, 1000000)
	result["xp"] = reward_kills * _zone_integer(zone.get("xp", 0), 0, 1000000)
	result["pet_xp"] = reward_kills * (2 + difficulty)
	result["rations"] = reward_kills * (4 + difficulty * 2)

	var progress := maxi(0, current_stage_kills) + kills
	var clear_limit := mini(MAX_OFFLINE_STAGE_CLEARS, MAX_STAGE - current_stage)
	var clears := mini(clear_limit, int(progress / stage_target))
	var stage := maxi(1, current_stage)
	var chest_gold := 0
	var chest_xp := 0
	var ration_bonus := 0
	for offset in clears:
		var cleared_stage := stage + offset
		var chest: Dictionary=preload("res://scripts/progression/GrowthEconomyRules.gd").stage_chest(cleared_stage)
		chest_gold += int(chest.gold)
		chest_xp += int(chest.xp)
		ration_bonus += int(chest.rations)
	progress -= clears * stage_target
	if clears >= clear_limit:
		progress = mini(progress, stage_target - 1)

	result["stage_clears"] = clears
	result["stage_kills"] = progress
	result["chest_gold"] = chest_gold
	result["chest_xp"] = chest_xp
	result["rations"] = int(result["rations"]) + ration_bonus
	var time_bonus := mini(8, int(elapsed_seconds / 1800.0))
	result["gear_rolls"] = mini(kills, mini(MAX_OFFLINE_GEAR_ROLLS, 10 + difficulty * 4 + time_bonus))
	return result
