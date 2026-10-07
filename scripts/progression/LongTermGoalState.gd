extends RefCounted
class_name LongTermGoalState

## Pure bounded save model. No time, reward, scene or filesystem side effects.
const C = preload("res://scripts/progression/LongTermGoalCatalog.gd")
const HEROES = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const MAX_COUNT: int = 1000000000

static func number(value: Variant, high: int = MAX_COUNT) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return 0
	return int(clampf(float(value), 0.0, float(high)))

static func dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

static func day_key(value: Variant) -> String:
	if typeof(value) != TYPE_STRING or value.length() != 10 or value[4] != "-" or value[7] != "-":
		return ""
	for character in value.replace("-", ""):
		if character < "0" or character > "9": return ""
	var year: int = int(value.substr(0, 4))
	var month: int = int(value.substr(5, 2))
	var day: int = int(value.substr(8, 2))
	if year < 1970 or year > 2100 or month < 1 or month > 12: return ""
	var leap: bool = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var days: Array[int] = [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return value if day > 0 and day <= days[month - 1] else ""

static func week_key(value: Variant) -> String:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 8 or not value.is_valid_int(): return ""
	var week: int = int(value)
	return str(week) if week >= 0 and week <= 10000 else ""

static func _counts(raw: Variant, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = dict(raw)
	for key: String in keys:
		result[key] = number(source.get(key, 0))
	return result

static func _flags(raw: Variant, entries: Array) -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = dict(raw)
	for entry: Dictionary in entries:
		var id: String = str(entry["id"])
		if typeof(source.get(id)) == TYPE_BOOL and source[id]: result[id] = true
	return result

static func sanitize(raw: Variant) -> Dictionary:
	var source: Dictionary = dict(raw)
	var state: Dictionary = {"schema": 1, "factions": {}}
	for scope: String in ["daily", "weekly"]:
		var period: Dictionary = dict(source.get(scope))
		var key: String = day_key(period.get("key")) if scope == "daily" else week_key(period.get("key"))
		state[scope] = {"key": key, "counts": _counts(period.get("counts"), C.EVENTS), "claimed": _flags(period.get("claimed"), C.entries(scope))}
		if key.is_empty():
			state[scope]["counts"] = _counts({}, C.EVENTS)
			state[scope]["claimed"] = {}
	for faction: String in C.FACTIONS:
		var bank: Dictionary = dict(dict(source.get("factions")).get(faction))
		var seen: Dictionary = {}
		var raw_seen: Dictionary = dict(bank.get("discovered"))
		for id: String in HEROES.HEROES:
			if str(HEROES.HEROES[id].get("faction", "")) == faction and typeof(raw_seen.get(id)) == TYPE_BOOL and raw_seen[id]:
				seen[id] = true
		var claimed: Dictionary = _flags(bank.get("achievements"), C.achievements())
		var equipped: String = str(bank.get("title", "")) if typeof(bank.get("title")) == TYPE_STRING else ""
		if not C.TITLES.has(equipped) or not bool(claimed.get(equipped, false)): equipped = ""
		var best: Dictionary = _counts(bank.get("best"), C.METRICS)
		best["stage"] = mini(int(best["stage"]), 10000)
		best["hero_level"] = mini(int(best["hero_level"]), 100)
		best["tower_best"] = mini(int(best["tower_best"]), 9999)
		state["factions"][faction] = {"totals": _counts(bank.get("totals"), C.EVENTS), "best": best,
			"guide_claimed": number(bank.get("guide_claimed"), C.GUIDE_COUNT), "achievements": claimed, "discovered": seen, "title": equipped}
	return state

static func advance_periods(state: Dictionary, day: String, week: String) -> void:
	for scope: String in ["daily", "weekly"]:
		var key: String = day_key(day) if scope == "daily" else week_key(week)
		if key.is_empty(): continue
		var old: String = str(state[scope]["key"])
		var newer: bool = old.is_empty() or (key > old if scope == "daily" else int(key) > int(old))
		if newer:
			state[scope] = {"key": key, "counts": _counts({}, C.EVENTS), "claimed": {}}
	# Clock rollback never refills a period or rewinds a claimed ledger.

static func observe(state: Dictionary, faction: String, metrics: Dictionary, ids: Array) -> void:
	if faction not in C.FACTIONS: return
	var bank: Dictionary = state["factions"][faction]
	for key: String in C.METRICS:
		var cap: int = 100 if key == "hero_level" else (9999 if key == "tower_best" else 10000)
		bank["best"][key] = maxi(int(bank["best"][key]), number(metrics.get(key), cap))
	for id: Variant in ids:
		if typeof(id) == TYPE_STRING and HEROES.HEROES.has(id) and str(HEROES.HEROES[id].get("faction", "")) == faction:
			bank["discovered"][id] = true

static func record(state: Dictionary, faction: String, event: String, amount: int, day: String, week: String) -> bool:
	if faction not in C.FACTIONS or event not in C.EVENTS or amount <= 0: return false
	advance_periods(state, day, week)
	var totals: Dictionary = state["factions"][faction]["totals"]
	totals[event] = mini(MAX_COUNT, int(totals[event]) + mini(amount, MAX_COUNT))
	for scope: String in ["daily", "weekly"]:
		var key: String = day if scope == "daily" else week
		if str(state[scope]["key"]) == key:
			state[scope]["counts"][event] = mini(MAX_COUNT, int(state[scope]["counts"][event]) + mini(amount, MAX_COUNT))
	return true

static func metric_value(state: Dictionary, faction: String, scope: String, metric: String) -> int:
	if faction not in C.FACTIONS: return 0
	var bank: Dictionary = state["factions"][faction]
	var counts: Dictionary = state[scope]["counts"] if scope in ["daily", "weekly"] else bank["totals"]
	if metric == "challenge_clear":
		var total: int = 0
		for key: String in ["daily_clear", "tower_clear", "abyss_clear", "raid_clear"]:
			total += int(counts.get(key, 0))
		return mini(MAX_COUNT, total)
	if metric == "guide_claimed": return int(bank["guide_claimed"])
	if metric == "discovered": return bank["discovered"].size()
	if metric in C.METRICS: return int(bank["best"].get(metric, 0))
	return int(counts.get(metric, 0))

static func status(state: Dictionary, faction: String, scope: String, id: String) -> Dictionary:
	var definition: Dictionary = C.find(scope, id)
	if definition.is_empty() or faction not in C.FACTIONS: return {}
	var value: Dictionary = definition.duplicate(true)
	var bank: Dictionary = state["factions"][faction]
	var claimed: bool = false
	var unlocked: bool = true
	if scope == "guide":
		claimed = int(definition["number"]) <= int(bank["guide_claimed"])
		unlocked = int(definition["number"]) <= int(bank["guide_claimed"]) + 1
	elif scope == "achievement":
		claimed = bool(bank["achievements"].get(id, false))
	else:
		claimed = bool(state[scope]["claimed"].get(id, false))
	var current: int = metric_value(state, faction, scope, str(definition["metric"]))
	value.merge({"current": mini(current, int(definition["target"])), "claimed": claimed, "unlocked": unlocked,
		"complete": current >= int(definition["target"]), "ready": unlocked and not claimed and current >= int(definition["target"])})
	return value

static func claim(state: Dictionary, faction: String, scope: String, id: String, expected: Dictionary, day: String, week: String) -> Dictionary:
	advance_periods(state, day, week)
	if str(expected.get("faction", "")) != faction or str(expected.get("scope", "")) != scope: return {"ok": false, "reason": "stale_context"}
	if scope in ["daily", "weekly"]:
		var key: String = day if scope == "daily" else week
		if key.is_empty() or str(state[scope]["key"]) != key or str(expected.get("key", "")) != key:
			return {"ok": false, "reason": "period_changed"}
	var goal: Dictionary = status(state, faction, scope, id)
	if goal.is_empty() or not bool(goal.get("ready", false)): return {"ok": false, "reason": "not_ready"}
	if scope == "guide":
		state["factions"][faction]["guide_claimed"] += 1
	elif scope == "achievement":
		state["factions"][faction]["achievements"][id] = true
	else:
		state[scope]["claimed"][id] = true
	return {"ok": true, "gold": int(goal["gold"]), "gems": int(goal["gems"]), "title": str(goal["title"])}

static func collection_tier(state: Dictionary, faction: String) -> int:
	if faction not in C.FACTIONS or not dict(state.get("factions")).has(faction): return 0
	var bank: Dictionary = state["factions"][faction]
	var tier: int = 0
	for count: int in [5, 10, 15]:
		if bool(bank["achievements"].get("collection_%d" % count, false)) and bank["discovered"].size() >= count: tier += 1
	return tier
