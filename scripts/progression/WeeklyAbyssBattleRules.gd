extends RefCounted

## Provisional encounter tuning, not a claim of tested end-user difficulty.
## One weekly ruleset for every attempt; party power never creates a score.
const LIMIT_SECONDS: float = 90.0
const WEEKLY_LIMIT: int = 5
const SCORE_VERSION: int = 1
const MAX_SCORE: int = 1000000000000
const MUTATORS: Array = [
	{"id": "fortified", "label": "강인한 심연", "description": "우두머리 최대 HP +25%", "hp_mult": 1.25, "attack_mult": 1.0, "speed_mult": 1.0},
	{"id": "ferocious", "label": "흉포한 심연", "description": "우두머리 공격력 +20%", "hp_mult": 1.0, "attack_mult": 1.2, "speed_mult": 1.0},
	{"id": "swift", "label": "가속된 심연", "description": "우두머리 공격 속도 +20%", "hp_mult": 1.0, "attack_mult": 1.0, "speed_mult": 1.2}
]

static func valid_week(week: String) -> bool:
	return not week.is_empty() and week.length() <= 12 and week.is_valid_int()

static func mutator(week: String) -> Dictionary:
	if not valid_week(week):
		return {}
	var index: int = ((int(week) % MUTATORS.size()) + MUTATORS.size()) % MUTATORS.size()
	return MUTATORS[index].duplicate(true)

static func plan(week: String) -> Dictionary:
	var rule: Dictionary = mutator(week)
	if rule.is_empty():
		return {}
	var pattern: Dictionary = preload("res://scripts/combat/ChallengePatternRules.gd").profile("weekly", 0, week)
	return {"mode": "weekly", "variant": str(rule["id"]), "title": "주간 심연 원정",
		"objective": "score", "limit_seconds": LIMIT_SECONDS, "required_waves": 0, "pattern": pattern,
		"description": "90초 생존 · 실제 HP 피해 점수 · " + str(rule["label"]) + "\n두 번째 무리부터 %s · %s\n지원몹 포함 실효 HP 피해 · 기존 최고점 보존(구패턴 기록과 동일조건 비교 아님)" % [pattern["label"], pattern["hint"]]}

static func enemy_stats(week: String, wave_index: int) -> Dictionary:
	var rule: Dictionary = mutator(week)
	if rule.is_empty() or wave_index < 0:
		return {}
	# Shared spawner doubles elite HP once. No hidden difficulty scaling by
	# attempt index or current party power; successive bosses have equal stats.
	return {"name": "철갑 두더지", "hp": int(9000.0 * float(rule["hp_mult"])),
		"attack": int(26.0 * float(rule["attack_mult"])), "elite": true, "boss": true,
		"attack_rate": float(rule["speed_mult"])}

static func reward(run_index: int) -> Dictionary:
	if run_index < 0 or run_index >= WEEKLY_LIMIT:
		return {}
	var completed: int = run_index + 1
	# Preserve the original five-completion reward schedule. No raid drops,
	# wallet XP or guardian XP are implicitly added by this content.
	return {"gold": 1200 + completed * 400, "gems": 15 + completed * 3,
		"hero_xp": 350 + completed * 100}
