extends RefCounted

## Encounter rules only: graphics, hero kits and reward amounts are reused.
## Tuning remains provisional until Godot integration/play tests are run.
## SaveValidation stores the NEXT floor up to 10000, so 9999 is the last
## settleable floor. Paying floor 10000 would be clamped back on reload.
const MAX_CLEAR_FLOOR: int = 9999
const LIMIT_SECONDS: float = 90.0
const FORMATIONS: Array = [
	{"label": "전열 돌파", "waves": [
		["가시 멧돼지", "초원 고블린", "바람 까마귀", "초원 고블린"],
		["광산 오크", "초원 고블린", "수정 거미", "바람 까마귀"]]},
	{"label": "후열 경계", "waves": [
		["초원 고블린", "들개 무리", "바람 까마귀", "초원 고블린"],
		["가시 멧돼지", "달빛 늑대", "수정 거미", "용암 박쥐"]]},
	{"label": "원거리 제압", "waves": [
		["광산 오크", "용암 박쥐", "밤까마귀", "수정 거미"],
		["철갑 두더지", "초원 고블린", "숲의 망령", "독버섯 정령"]]}
]
const BOSS_WAVE: Array[String] = ["철갑 두더지", "용암 박쥐", "수정 거미"]

static func valid_floor(floor_number: int) -> bool:
	return floor_number >= 1 and floor_number <= MAX_CLEAR_FLOOR

static func is_boss_floor(floor_number: int) -> bool:
	return valid_floor(floor_number) and floor_number % 5 == 0

static func plan(floor_number: int) -> Dictionary:
	if not valid_floor(floor_number):
		return {}
	var formation: Dictionary = FORMATIONS[(floor_number - 1) % FORMATIONS.size()]
	var waves: int = 3 if is_boss_floor(floor_number) else 2
	var pattern: Dictionary = preload("res://scripts/ChallengePatternRules.gd").profile("tower", floor_number)
	return {"mode": "tower", "variant": "floor", "title": "무한탑 %d층" % floor_number,
		"objective": "waves", "limit_seconds": LIMIT_SECONDS, "required_waves": waves, "pattern": pattern,
		"description": "90초 안에 %d개 무리 격파 · %s%s" % [waves, formation["label"],
			" · 마지막 무리 정예 수문장과 호위" if is_boss_floor(floor_number) else ""] + ("\n마지막 무리 · %s · %s" % [pattern["label"], pattern["hint"]] if not pattern.is_empty() else "")}

static func wave_names(floor_number: int, wave_index: int) -> Array:
	if not valid_floor(floor_number) or wave_index < 0:
		return []
	if is_boss_floor(floor_number) and wave_index == 2:
		return BOSS_WAVE.duplicate()
	if wave_index >= 2:
		return []
	var formation: Dictionary = FORMATIONS[(floor_number - 1) % FORMATIONS.size()]
	var waves: Array = formation["waves"]
	return waves[wave_index].duplicate()

static func enemy_count(floor_number: int, wave_index: int) -> int:
	return wave_names(floor_number, wave_index).size()

static func enemy_stats(floor_number: int, wave_index: int, enemy_index: int) -> Dictionary:
	var names: Array = wave_names(floor_number, wave_index)
	if enemy_index < 0 or enemy_index >= names.size():
		return {}
	var boss: bool = is_boss_floor(floor_number) and wave_index == 2 and enemy_index == 0
	# Shared spawner doubles elite HP once; these are pre-elite values.
	var hp: int = 850 + floor_number * 110 if boss else 100 + floor_number * 28 + wave_index * 20 + (enemy_index % 2) * 12
	var attack: int = 20 + floor_number * 5 if boss else 8 + floor_number * 3 + wave_index * 2
	return {"name": str(names[enemy_index]), "hp": hp, "attack": attack, "elite": boss, "boss": boss}

static func recommended_power(floor_number: int) -> int:
	return 500 + floor_number * 180 if valid_floor(floor_number) else 0

static func reward(floor_number: int) -> Dictionary:
	if not valid_floor(floor_number):
		return {}
	# Original v79 reward schedule, integer gems. No daily quota or XP award.
	return {"gold": 250 + floor_number * 90, "gems": 2 + int(floor_number / 5.0)}
