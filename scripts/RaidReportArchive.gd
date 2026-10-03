extends RefCounted
## Optional local analytics. Never loads into wallet/hero state or blocks rewards.
const PATH: String = "user://raid_contribution_v1.json"
const MAX_REPORTS: int = 12
const MAX_BYTES: int = 262144
const NUMBERS: Array[String] = ["damage","boss_damage","guard_damage","add_damage","damage_taken","healing_received","healing_given","shield_given","shield_absorbed","interrupts","hp","max_hp","slot","first_down_at","dps"]
# Per-channel caps are set by the producer. Damage has THREE channels;
# total damage and actor damage may legitimately reach three times that cap.
const CHANNEL_CAP: int = 1000000000000
const DAMAGE_CAP: int = CHANNEL_CAP * 3
const TOTAL_KEYS: Array[String] = ["boss_damage", "guard_damage", "add_damage", "healing_given", "shield_given", "interrupts"]

static func _number(value: Variant, minimum: float, maximum: float, integral: bool) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
	var n: float = float(value)
	return is_finite(n) and n >= minimum and n <= maximum and (not integral or fmod(n, 1.0) == 0.0)

static func clean(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _number(raw.get("schema", 0), 1.0, 1.0, true) or raw.get("rule", "") != "raid-contribution-1": return {}
	var e: Variant = raw.get("entry", {})
	if not e is Dictionary or str(e.get("faction", "")) not in ["aurelia", "noxfera"] or str(e.get("zone", "")) not in ["gray_meadow", "forgotten_mine", "moonrest_forest"]: return {}
	var rows: Variant = raw.get("actors", [])
	if not rows is Array or rows.size() > 12 or rows.is_empty(): return {}
	var result: Dictionary = {"schema":1, "rule":"raid-contribution-1", "stamp":str(raw.get("stamp", "")).left(96),
		"entry":{"faction":str(e["faction"]), "zone":str(e["zone"]), "name":str(e.get("name", "")).left(80), "auto_skill":e.get("auto_skill",true)==true, "auto_ultimate":e.get("auto_ultimate",true)==true},
		"reason":str(raw.get("reason", "")).left(32), "actors":[], "totals":{}}
	# Older reports remain readable; new reports retain the actual entry difficulty.
	if e.has("balance_revision") or e.has("max_hp") or e.has("attack"):
		if typeof(e.get("balance_revision")) != TYPE_STRING or str(e["balance_revision"]).is_empty(): return {}
		for key: String in ["max_hp", "attack"]:
			if not _number(e.get(key), 1.0, float(CHANNEL_CAP), true): return {}
			result.entry[key] = int(e[key])
		result.entry["balance_revision"] = str(e["balance_revision"]).left(80)
	for k: String in ["serial", "elapsed", "alive", "total_damage"]:
		var n: Variant = raw.get(k, 0)
		var ceiling: float = float(DAMAGE_CAP if k == "total_damage" else CHANNEL_CAP)
		if not _number(n, 0.0, ceiling, k != "elapsed"): return {}
		# Canonical numeric types make original and JSON-restored receipts agree.
		if k == "elapsed": result[k] = float(n)
		else: result[k] = int(n)
	var seen: Dictionary = {}
	for row in rows:
		if not row is Dictionary: return {}
		var id: String = str(row.get("id", ""))
		var hero: Dictionary = preload("res://scripts/HeroRosterCatalog.gd").hero(id)
		if seen.has(id) or (hero.is_empty() and id not in ["$support", "$unknown"]): return {}
		if not hero.is_empty() and str(hero.get("faction", "")) != result.entry.faction: return {}
		seen[id] = true
		var out: Dictionary = {"id":id, "name":str(row.get("name", id)).left(60), "role":str(row.get("role", "")).left(32)}
		for k: String in NUMBERS:
			var n: Variant = row.get(k, 0)
			var floating: bool = k in ["dps", "first_down_at"]
			var ceiling: float = INF if k == "dps" else float(DAMAGE_CAP if k == "damage" else CHANNEL_CAP)
			if not _number(n, -1.0 if k == "first_down_at" else 0.0, ceiling, not floating): return {}
			if floating: out[k] = float(n)
			else: out[k] = int(n)
		result.actors.append(out)
	var totals: Variant = raw.get("totals", {})
	if not totals is Dictionary: return {}
	for k: String in TOTAL_KEYS:
		var n: Variant = totals.get(k, 0)
		if not _number(n, 0.0, float(CHANNEL_CAP), true): return {}
		result.totals[k] = int(n)
	if not _consistent(result): return {}
	return result

static func _consistent(report: Dictionary) -> bool:
	var sums: Dictionary = {}
	for key: String in TOTAL_KEYS: sums[key] = 0
	var damage: int = 0
	var alive: int = 0
	var heroes: int = 0
	var seconds: float = float(report.elapsed)
	for row: Dictionary in report.actors:
		var channel_damage: int = int(row.boss_damage) + int(row.guard_damage) + int(row.add_damage)
		if int(row.damage) != channel_damage: return false
		var dps: float = float(channel_damage) / seconds if seconds > 0.0 else 0.0
		# A local JSON roundtrip may round floats. It must not turn an arbitrary
		# stored DPS into a trusted comparison value; recompute after validation.
		if not is_finite(dps) or absf(float(row.dps) - dps) > maxf(0.000001, absf(dps) * 0.000001): return false
		row.dps = dps
		for key: String in TOTAL_KEYS: sums[key] = int(sums[key]) + int(row[key])
		damage += channel_damage
		if not str(row.id).begins_with("$"):
			heroes += 1
			if int(row.hp) > 0: alive += 1
	if heroes > 10 or int(report.alive) != alive or int(report.total_damage) != damage: return false
	for key: String in TOTAL_KEYS:
		if int(report.totals[key]) != int(sums[key]): return false
	return true
static func load_reports(path: String = PATH) -> Array:
	if not FileAccess.file_exists(path): return []
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES: return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return []
	var data: Variant = json.data
	if not data is Dictionary or data.get("version",0)!=1 or not data.get("reports",null) is Array: return []
	var reports: Array=[]
	for raw in data["reports"].slice(0,MAX_REPORTS):
		var valid:=clean(raw)
		if not valid.is_empty(): reports.append(valid)
	return reports
static func _same_receipt(old: Dictionary, current: Dictionary) -> bool:
	# Legacy files used JSON's default float precision. Accept only tiny rounding
	# differences in elapsed/first-down times; all counters and identity fields
	# must still match exactly. Derived DPS has already been independently checked.
	if not _roundtrip_equal(float(old.elapsed), float(current.elapsed)): return false
	if old.actors.size() != current.actors.size(): return false
	var comparable: Dictionary = current.duplicate(true)
	comparable.elapsed = old.elapsed
	for index in old.actors.size():
		var a: Dictionary = old.actors[index]
		var b: Dictionary = comparable.actors[index]
		if not _roundtrip_equal(float(a.first_down_at), float(b.first_down_at)): return false
		b.first_down_at = a.first_down_at
		b.dps = a.dps
	return old == comparable

static func _roundtrip_equal(a: float, b: float) -> bool:
	if a == b: return true
	if a == 0.0 or b == 0.0 or a < 0.0 or b < 0.0: return false
	return absf(a - b) <= maxf(absf(a), absf(b)) * 0.000000000001

static func append(path: String, report: Dictionary) -> bool:
	var valid:=clean(report)
	if valid.is_empty():return false
	var reports:=load_reports(path)
	for old in reports:
		if old["stamp"]==valid["stamp"]: return _same_receipt(old, valid)
	reports.push_front(valid)
	if reports.size()>MAX_REPORTS:reports.resize(MAX_REPORTS)
	var data:=JSON.stringify({"version":1,"reports":reports}, "", true, true)
	if data.to_utf8_buffer().size()>MAX_BYTES:return false
	var temporary:=path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_string(data);file.flush()
	var error: Error=file.get_error();file.close()
	if error!=OK:return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))==OK
