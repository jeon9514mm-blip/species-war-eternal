extends RefCounted
class_name CombatStatusRules

const KEYS := {"stun":"stun_seconds", "weaken":"weaken_seconds", "vulnerable":"vulnerable_seconds"}

static func remaining(enemy: Dictionary, kind: String) -> float:
	if not KEYS.has(kind) or int(enemy.get("hp", 0)) <= 0:
		return 0.0
	var value := float(enemy.get(KEYS[kind], 0.0))
	return maxf(0.0, value) if is_finite(value) else 0.0

static func apply(enemy: Dictionary, kind: String, duration: float) -> bool:
	if not KEYS.has(kind) or int(enemy.get("hp", 0)) <= 0 or not is_finite(duration) or duration <= 0.0:
		return false
	# Recasts never add durations; keep the stronger remaining duration only.
	var before := remaining(enemy, kind)
	enemy[KEYS[kind]] = maxf(before, minf(duration, 30.0))
	return float(enemy[KEYS[kind]]) > before
