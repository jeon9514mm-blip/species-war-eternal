extends RefCounted
## Recent completed corps calibrate offline pack throughput in game seconds.
## Reports are scoped by faction, region, party, formation and auto settings.
const MIN_PACKS := 12
const ZONES := ["gray_meadow", "forgotten_mine", "moonrest_forest"]

static func party_signature(main: Node) -> Dictionary:
	var ids: Array = main._deployed_hero_ids().duplicate()
	ids.sort()
	var loadout: Dictionary = {}
	for hero_id: String in ids:
		loadout[hero_id] = {"items":main.hero_equipment_items.get(hero_id, {}),
			"levels":main.hero_equipment.get(hero_id, {}), "rarities":main.hero_equipment_rarity.get(hero_id, {}),
			"sets":main.hero_equipment_sets.get(hero_id, {}), "research":main.hero_skill_tree.get(hero_id, {})}
	# JSON parsing normalizes int/float representations across a save round trip.
	var build := JSON.stringify(JSON.parse_string(JSON.stringify(loadout))).sha256_text()
	return {"hero_ids":ids, "formation":str(main.formation_id), "guardian":str(main.guardian_equipped),
		"build":build, "skill_auto":bool(main.skill_auto), "ultimate_auto":bool(main.ultimate_auto)}

static func key(main: Node, zone_id: String) -> String:
	return str(main.selected_faction) + "/" + zone_id

static func begin_sample(main: Node) -> void:
	main.set_meta("hunt_sample", {"signature":party_signature(main), "origin":float(main.invasion.clock), "packs":0})

static func record(main: Node, packs: int) -> void:
	if packs <= 0 or main.challenge_session != null or bool(main.get_meta("practice_active", false)): return
	var signature := party_signature(main)
	var sample: Dictionary = main.get_meta("hunt_sample", {})
	if sample.is_empty() or sample.get("signature") != signature:
		begin_sample(main)
		return
	sample["packs"] = int(sample["packs"]) + packs
	var seconds := float(main.invasion.clock) - float(sample["origin"])
	if seconds < 4.0 or int(sample["packs"]) < MIN_PACKS: return
	var entry := signature.duplicate(true)
	entry["seconds_per_pack"] = clampf(seconds / float(sample["packs"]), 0.1, 3600.0)
	entry["power"] = int(main._calculate_party_power())
	entry["stage"] = int(main.idle_stage)
	main.hunt_productivity[key(main, str(main.current_zone_id))] = entry

static func observed(main: Node, zone_id: String) -> Dictionary:
	var entry: Dictionary = main.hunt_productivity.get(key(main, zone_id), {})
	if entry.is_empty(): return {}
	var signature := party_signature(main)
	for field in signature:
		if entry.get(field) != signature[field]: return {}
	# Reusing a strong party's pace after stripping its levels/gear is invalid.
	if int(main._calculate_party_power()) < int(entry.get("power", 0)) * 0.9: return {}
	if int(main.idle_stage) < int(entry.get("stage", 1)) - 5: return {}
	var result := entry.duplicate(true)
	var unlock_stage: int = int(main._zone_data()[zone_id].get("unlock_stage", 1))
	var ecology = preload("res://scripts/hunting/FieldEcology.gd")
	var old_pressure: float = ecology.stage_pressure(int(entry["stage"]), unlock_stage)
	var new_pressure: float = ecology.stage_pressure(int(main.idle_stage), unlock_stage)
	result["seconds_per_pack"] = float(entry["seconds_per_pack"]) * maxf(1.0, new_pressure / old_pressure)
	return result

static func sanitize(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary: return clean
	for faction: String in ["aurelia", "noxfera"]:
		for zone: String in ZONES:
			var id := faction + "/" + zone
			var value: Variant = raw.get(id)
			if not value is Dictionary: continue
			var seconds: Variant = value.get("seconds_per_pack")
			if typeof(seconds) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(seconds)) or float(seconds) < 0.1 or float(seconds) > 3600.0: continue
			var ids: Variant = value.get("hero_ids")
			if not ids is Array or ids.is_empty() or ids.size() > 10: continue
			var heroes: Array = []
			for hero_id: Variant in ids:
				if typeof(hero_id) == TYPE_STRING and hero_id.length() <= 64 and hero_id not in heroes: heroes.append(hero_id)
			if heroes.size() != ids.size(): continue
			heroes.sort()
			var power: Variant = value.get("power")
			var stage: Variant = value.get("stage")
			var build: Variant = value.get("build")
			if typeof(build) != TYPE_STRING or build.length() != 64: continue
			if typeof(power) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(power)) or float(power) <= 0: continue
			if typeof(stage) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(stage)): continue
			clean[id] = {"hero_ids":heroes, "seconds_per_pack":float(seconds), "power":int(clampf(float(power),1,1000000000)),
				"stage":int(clampf(float(stage),1,10000)), "formation":str(value.get("formation", "")).substr(0,32),
				"guardian":str(value.get("guardian", "")).substr(0,32), "build":build,
				"skill_auto":typeof(value.get("skill_auto")) == TYPE_BOOL and value["skill_auto"],
				"ultimate_auto":typeof(value.get("ultimate_auto")) == TYPE_BOOL and value["ultimate_auto"]}
	return clean
