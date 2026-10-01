extends RefCounted
## Observation only: direct committed HP deltas, not calculated/overkill damage.
const BASE = preload("res://scripts/ChallengeCombatLedger.gd")
const CAP: int = 1000000000000
var serial: int = -1
var closed: bool = true
var actors: Dictionary = {}
var totals: Dictionary = {}
var entry: Dictionary = {}
func begin(token: int, roster: Array, states: Dictionary, context: Dictionary) -> void:
	serial = token; closed = false; entry = context.duplicate(true)
	var base = BASE.new(); base.begin(roster, states, true, true)
	actors = base.actors.duplicate(true)
	totals = {"boss_damage":0,"guard_damage":0,"add_damage":0,"healing_given":0,"shield_given":0,"interrupts":0}
	for row in actors.values():
		for key in totals: row[key] = 0
	actors["$support"] = {"id":"$support", "name":"수호신·지원", "role":"지원", "slot":100}
	actors["$unknown"] = {"id":"$unknown", "name":"출처 미분류", "role":"미분류", "slot":101}
	for id in ["$support", "$unknown"]:
		for key in totals: actors[id][key] = 0
func add(token: int, source: String, kind: String, amount: int) -> void:
	if closed or token != serial or not totals.has(kind) or amount <= 0: return
	var id: String = source if actors.has(source) else "$unknown"
	var value: int = mini(amount, CAP - int(totals[kind]))
	totals[kind] += value; actors[id][kind] += value
func incoming(token: int, id: String, before: int, after: int, absorbed: int, elapsed: float) -> void:
	if closed or token != serial or not actors.has(id) or id.begins_with("$") or before <= 0 or after < 0 or after > before: return
	var row: Dictionary = actors[id]
	row["damage_taken"] = mini(CAP, int(row["damage_taken"]) + before - after)
	row["shield_absorbed"] = mini(CAP, int(row["shield_absorbed"]) + maxi(0, absorbed))
	if after == 0 and float(row["first_down_at"]) < 0.0: row["first_down_at"] = maxf(0.0, elapsed)
func healed(token: int, target: String, amount: int) -> void:
	if closed or token != serial or not actors.has(target) or target.begins_with("$") or amount <= 0: return
	actors[target]["healing_received"] = mini(CAP, int(actors[target]["healing_received"]) + amount)
func finish(token: int, outcome: String, elapsed: float, states: Dictionary) -> Dictionary:
	if closed or token != serial or actors.is_empty(): return {}
	closed = true
	var rows: Array = []; var alive: int = 0
	for id in actors:
		var row: Dictionary = actors[id].duplicate(true)
		row["damage"] = int(row["boss_damage"]) + int(row["guard_damage"]) + int(row["add_damage"])
		if not id.begins_with("$"):
			row["hp"] = maxi(0,int(states.get(id,{}).get("hp",0)))
			if row["hp"] > 0: alive += 1
		row["dps"] = float(row["damage"]) / elapsed if elapsed > 0.0 else 0.0
		rows.append(row)
	return {"schema":1,"rule":"raid-contribution-1","serial":serial,"entry":entry.duplicate(true),
		"reason":outcome,"elapsed":elapsed,"alive":alive,"actors":rows,"totals":totals.duplicate(true),
		"total_damage":int(totals["boss_damage"])+int(totals["guard_damage"])+int(totals["add_damage"])}
