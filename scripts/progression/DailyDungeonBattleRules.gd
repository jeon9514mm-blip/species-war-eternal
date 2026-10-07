extends RefCounted

## Shared daily quota and reward schedule. Mode changes do not multiply rewards.
## Enemy tuning is provisional until actual engine/device playtesting.
const VARIANTS: Array[String] = ["gold_rush", "survival", "boss_hunt"]
const DAILY_LIMIT: int = 3

static func plan(variant: String = "gold_rush") -> Dictionary:
	match variant:
		"gold_rush":
			return {"mode": "daily", "variant": variant, "title": "골드 러시",
				"objective": "waves", "limit_seconds": 60.0, "required_waves": 3,
				"description": "60초 안에 3개 무리를 격파하세요."}
		"survival":
			return {"mode": "daily", "variant": variant, "title": "생존전",
				"objective": "survive", "limit_seconds": 60.0, "required_waves": 0,
				"description": "반복 등장하는 적을 상대하며 60초 동안 생존하세요."}
		"boss_hunt":
			return {"mode": "daily", "variant": variant, "title": "보스 토벌",
				"objective": "waves", "limit_seconds": 60.0, "required_waves": 1,
				"description": "60초 안에 강화된 정예 우두머리 1마리를 처치하세요."}
	return {}

static func reward(run_index: int) -> Dictionary:
	if run_index < 0 or run_index >= DAILY_LIMIT:
		return {}
	var completed: int = run_index + 1
	return {"gold": 700 + completed * 250, "xp": 250 + completed * 100, "pet_xp": 60}

static func enemy_count(variant: String) -> int:
	match variant:
		"gold_rush": return 6
		"survival": return 4
		"boss_hunt": return 1
	return 0

static func enemy_stats(run_index: int, wave_index: int, enemy_index: int, variant: String = "gold_rush") -> Dictionary:
	if run_index < 0 or run_index >= DAILY_LIMIT or wave_index < 0 or enemy_index < 0 or enemy_index >= enemy_count(variant):
		return {}
	var tier: int = run_index
	if variant == "survival":
		var pressure: int = mini(wave_index, 4)
		return {"hp": 90 + tier * 24 + pressure * 18, "attack": 11 + tier * 3 + pressure * 2,
			"elite": pressure >= 2 and enemy_index == 0, "boss": false}
	if variant == "boss_hunt":
		return {"hp": 625 + tier * 250, "attack": 24 + tier * 6, "elite": true, "boss": true}
	var wave: int = mini(wave_index, 2)
	return {"hp": 105 + tier * 42 + wave * 25 + (enemy_index % 2) * 18,
		"attack": 7 + tier * 3 + wave * 2, "elite": wave == 2 and enemy_index == 0, "boss": false}
