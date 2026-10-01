extends RefCounted

## Only direct, settled victories unlock this faction/mode/tier. Missing legacy
## data remains locked: old power-check clears are not proof of a real victory.
const RULES = preload("res://scripts/DailyDungeonBattleRules.gd")
const FACTIONS: Array[String] = ["aurelia", "noxfera"]

static func clear_key(faction: String, variant: String, tier: int) -> String:
	if faction not in FACTIONS or variant not in RULES.VARIANTS or tier < 0 or tier >= RULES.DAILY_LIMIT:
		return ""
	return "%s:%s:%d" % [faction, variant, tier]

static func sanitize(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return clean
	# Enumerate the allowlist, not arbitrary keys from an untrusted save.
	for faction in FACTIONS:
		for variant in RULES.VARIANTS:
			for tier in RULES.DAILY_LIMIT:
				var key: String = clear_key(faction, variant, tier)
				if typeof(raw.get(key)) == TYPE_BOOL and raw[key]:
					clean[key] = true
	return clean

static func can_sweep(clears: Dictionary, faction: String, variant: String, tier: int) -> bool:
	var key: String = clear_key(faction, variant, tier)
	return not key.is_empty() and typeof(clears.get(key)) == TYPE_BOOL and clears[key] == true

static func record_direct_clear(clears: Dictionary, faction: String, variant: String, tier: int) -> bool:
	var key: String = clear_key(faction, variant, tier)
	if key.is_empty():
		return false
	clears[key] = true
	return true
