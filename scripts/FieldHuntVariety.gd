extends RefCounted
class_name FieldHuntVariety

# v77 keeps encounter variety deterministic from runtime encounter identity so
# tests and resumed sessions do not depend on wall-clock randomness.
const EVENT_STANDARD := "standard"
const EVENT_ELITE := "elite_patrol"
const EVENT_TREASURE := "treasure_hunt"
const EVENT_AMBUSH := "ambush"
const EVENT_LUCKY := "lucky_find"

const EVENT_LABELS := {
	EVENT_STANDARD: "평온한 순찰",
	EVENT_ELITE: "정예 순찰대",
	EVENT_TREASURE: "보물 몬스터",
	EVENT_AMBUSH: "기습 조우",
	EVENT_LUCKY: "행운의 흔적"
}

const AFFIXES := ["ironhide", "frenzied", "keen"]
const AFFIX_LABELS := {
	"ironhide": "철갑",
	"frenzied": "광전",
	"keen": "추적"
}

static func _zone_code(zone_id: String) -> int:
	match zone_id:
		"forgotten_mine": return 29
		"moonrest_forest": return 47
		_: return 11

static func _seed(encounter_id: int, stage: int, difficulty: int, zone_id: String) -> int:
	return maxi(1, encounter_id * 7919 + stage * 313 + difficulty * 97 + _zone_code(zone_id) * 53)

static func encounter_profile(encounter_id: int, stage: int, difficulty: int, zone_id: String) -> Dictionary:
	var profile := {
		"type": EVENT_STANDARD,
		"label": EVENT_LABELS[EVENT_STANDARD],
		"population_bonus": 0,
		"enemy_attack_mult": 1.0,
		"reward_mult": 1.0,
		"elite_count": 0,
		"treasure_seconds": 0.0,
		"guaranteed_rare": false
	}
	# Keep the opening tutorial and first-stage balance exactly as before.
	if stage < 2:
		return profile
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed(encounter_id, stage, difficulty, zone_id)
	var roll := rng.randi_range(0, 99)
	var event_type := EVENT_STANDARD
	if roll < 6:
		event_type = EVENT_TREASURE
	elif roll < 15:
		event_type = EVENT_ELITE
	elif roll < 22:
		event_type = EVENT_AMBUSH
	elif roll < 28:
		event_type = EVENT_LUCKY
	profile["type"] = event_type
	profile["label"] = EVENT_LABELS[event_type]
	match event_type:
		EVENT_ELITE:
			profile["population_bonus"] = 1
			profile["elite_count"] = 2 if difficulty >= 2 else 1
			profile["reward_mult"] = 1.12
		EVENT_TREASURE:
			profile["treasure_seconds"] = 12.0 + float(difficulty)
		EVENT_AMBUSH:
			profile["population_bonus"] = 2
			profile["enemy_attack_mult"] = 1.10
			profile["reward_mult"] = 1.10
		EVENT_LUCKY:
			profile["reward_mult"] = 1.05
			profile["guaranteed_rare"] = true
	return profile

static func elite_affix(encounter_id: int, enemy_index: int, zone_id: String) -> String:
	var value := absi(encounter_id * 17 + enemy_index * 7 + _zone_code(zone_id))
	return AFFIXES[value % AFFIXES.size()]

static func affix_label(affix: String) -> String:
	return str(AFFIX_LABELS.get(affix, "정예"))

static func apply_elite_affix(enemy: Dictionary, affix: String) -> void:
	if enemy.is_empty():
		return
	var max_hp := maxi(1, int(enemy.get("max_hp", 1)))
	var attack := maxi(1, int(enemy.get("attack", 1)))
	match affix:
		"ironhide":
			max_hp = maxi(1, int(round(float(max_hp) * 1.28)))
			attack = maxi(1, int(round(float(attack) * 1.05)))
		"frenzied":
			max_hp = maxi(1, int(round(float(max_hp) * 1.10)))
			attack = maxi(1, int(round(float(attack) * 1.24)))
		"keen":
			max_hp = maxi(1, int(round(float(max_hp) * 1.14)))
			attack = maxi(1, int(round(float(attack) * 1.14)))
			enemy["sight_radius"] = minf(4.0, float(enemy.get("sight_radius", 2.4)) + 0.55)
			enemy["leash_radius"] = float(enemy.get("leash_radius", 2.8)) + 0.30
	enemy["elite_affix"] = affix
	enemy["max_hp"] = max_hp
	enemy["hp"] = max_hp
	enemy["attack"] = attack
	enemy["base_attack"] = attack

static func combo_bonus(combo: int) -> float:
	# 2.5% per uninterrupted clear, capped at +25%.
	return minf(0.25, float(maxi(0, combo - 1)) * 0.025)

static func combo_window(difficulty: int) -> float:
	return 25.0 - float(clampi(difficulty, 1, 3) - 1) * 1.5
