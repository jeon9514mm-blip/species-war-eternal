extends SceneTree

const RULES = preload("res://scripts/EquipmentRules.gd")
const WORKSHOP = preload("res://scripts/EquipmentWorkshop.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _item(rarity := "전설") -> Dictionary:
	return RULES.normalize({"id": "fixture", "slot": "weapon", "level": 3, "rarity": rarity,
		"name": "검사 장비", "set": "개척자", "origin": "hunt", "source_id": "gray_meadow"})

func _same_failure(result: Dictionary, original: Dictionary, balance: int, label: String) -> void:
	_check(not result["ok"] and result["item"] == original and int(result["balance"]) == balance and int(result["cost"]) == 0, label)

func _test_normalization() -> void:
	var legacy := {"id": "old_gear", "slot": "armor", "level": 8, "rarity": "희귀", "name": "월광 비늘갑옷", "set": "월광", "zone": "달잠 숲"}
	var original := legacy.duplicate(true)
	var gear := RULES.normalize(legacy)
	_check(legacy == original, "normalization does not mutate legacy inventory")
	for key in legacy:
		_check(gear[key] == legacy[key], "legacy field preserved: %s" % key)
	_check(gear["power"] == int(8 * 16 * 1.45), "legacy equipment power formula unchanged")
	_check(gear["origin"] == "legacy" and gear["affixes"].is_empty(), "legacy items gain no unearned stat rolls")
	_check(RULES.normalize({"slot": []}).is_empty(), "invalid slot type rejected")
	_check(RULES.normalize({"slot": "helmet"}).is_empty(), "unsupported slot rejected")
	var malformed := _item()
	malformed.merge({"level": INF, "rarity": [], "origin": {}, "focus": NAN, "trade_count": "1", "bound": "false", "locked": [true], "name": 123, "set": {}, "affixes": {}}, true)
	gear = RULES.normalize(malformed)
	_check(gear["level"] == 1 and gear["focus"] == 0 and gear["trade_count"] == 0, "nonfinite or malformed numbers safely default")
	_check(gear["rarity"] == "일반" and gear["origin"] == "legacy" and gear["set"] == "초보자", "unknown enum values safely default")
	_check(not gear["bound"] and not gear["locked"] and gear["name"] == "미확인 장비", "invalid booleans and string fields are not coerced")
	_check(gear["affixes"].is_empty(), "non-array affixes discarded")
	var raw := _item()
	raw["affixes"] = [null, [], {"stat": "attack_pct", "value": NAN}, {"stat": "attack_pct", "value": 99}, {"stat": "attack_pct", "value": 3}, {"stat": "hp_pct", "value": -2}, {"stat": "haste_pct", "value": "3"}, {"stat": "defense", "value": 2}, {"stat": "hp_pct", "value": 5}, {"stat": "ultimate_pct", "value": 3}]
	gear = RULES.normalize(raw)
	_check(gear["affixes"] == [{"stat": "attack_pct", "value": 6}, {"stat": "defense", "value": 2}, {"stat": "hp_pct", "value": 5}], "affix types, unique stats, ranges, and rarity capacity normalized")
	for rarity in RULES.RARITIES:
		raw["rarity"] = rarity
		_check(RULES.normalize(raw)["affixes"].size() == RULES.option_capacity(raw), "%s capacity respected" % rarity)
	raw = _item()
	raw["affixes"] = [{"stat": "attack_pct", "value": 4}]
	raw["proposal"] = {"family": "assault", "cost": -100, "options": [{"stat": "attack_pct", "value": 6}, {"stat": "defense", "value": 4}, {"stat": "ultimate_pct", "value": 999}, {"stat": "ultimate_pct", "value": 2}]}
	gear = RULES.normalize(raw)
	_check(gear["proposal"] == {"family": "assault", "cost": 20, "options": [{"stat": "ultimate_pct", "value": 5}]}, "stored proposal validated against family, duplicate stats, range, and expected cost")
	var loaded: Variant = JSON.parse_string(JSON.stringify(gear))
	_check(loaded is Dictionary and RULES.normalize(loaded) == gear, "pending proposal and metadata survive JSON save/load without reroll")
	raw["proposal"] = {"family": [], "options": {}}
	_check(RULES.normalize(raw)["proposal"].is_empty(), "malformed proposal containers discarded")
	gear = RULES.normalize({"id": "", "level": 99, "focus": 99, "trade_count": 99})
	_check(str(gear["id"]).begins_with("gear_") and str(gear["id"]).length() == 37, "missing identifiers receive 128-bit random equipment IDs")
	_check(gear["level"] == 10 and gear["focus"] == 3 and gear["trade_count"] == 1, "bounded integer fields clamp")

func _test_generation_and_sets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5401
	var seen: Dictionary = {}
	for source_id in RULES.ZONES:
		for slot in RULES.SLOTS:
			for rarity in RULES.RARITIES:
				for raid in [false, true]:
					var gear := RULES.raid_item(source_id, slot, rarity, rng) if raid else RULES.hunt_item(source_id, slot, rarity, rng)
					_check(not seen.has(gear["id"]), "new loot instance has a unique identifier")
					seen[gear["id"]] = true
					_check(gear["origin"] == ("raid" if raid else "hunt") and gear["source_id"] == source_id and gear["slot"] == slot and gear["rarity"] == rarity, "generated item retains source and slot identity")
					_check(gear["set"] == RULES.ZONES[source_id]["raid_set" if raid else "set"] and gear["affixes"].is_empty(), "field and raid sets remain distinct without free affixes")
		var region: Dictionary = RULES.ZONES[source_id]
		var from_dict := RULES.hunt_item({"name": region["name"], "equipment_set": region["set"]}, "weapon", "일반", rng)
		_check(from_dict["source_id"] == source_id, "existing Main zone dictionary resolves correct equipment region")
	var expectations := {
		"초보자": [1.0, 1.0, 0, 0, 0], "개척자": [1.05, 1.08, 0, 0, 0],
		"강철": [1.0, 1.08, 5, 0, 0], "월광": [1.12, 1.06, 0, 0, 0],
		"새벽의 맹약": [1.0, 1.10, 0, 0, 8], "철벽의 맹세": [1.0, 1.12, 8, 0, 0], "월식의 추격": [1.10, 1.0, 0, 6, 0],
	}
	for set_name in expectations:
		var profile := RULES.set_profile({"weapon": set_name, "armor": set_name, "accessory": set_name})
		var expected: Array = expectations[set_name]
		_check(is_equal_approx(profile["attack_mult"], expected[0]) and is_equal_approx(profile["hp_mult"], expected[1]) and profile["defense_bonus"] == expected[2] and profile["haste_pct"] == expected[3] and profile["ultimate_pct"] == expected[4], "three-piece set effects: %s" % set_name)
		var single := RULES.set_profile({"weapon": set_name})
		_check(single["attack_mult"] == 1.0 and single["hp_mult"] == 1.0 and single["defense_bonus"] == 0 and single["haste_pct"] == 0 and single["ultimate_pct"] == 0, "one piece never activates set: %s" % set_name)
	var pieces: Array = []
	for _n in 10:
		for stat in RULES.STAT_RANGES:
			var gear := _item()
			gear["affixes"] = [{"stat": stat, "value": RULES.STAT_RANGES[stat].y}]
			pieces.append(gear)
	_check(RULES.affix_profile(pieces) == RULES.STAT_CAPS, "summed affixes obey every stat cap")

func _test_workshop() -> void:
	var rng := RandomNumberGenerator.new()
	var twin_rng := RandomNumberGenerator.new()
	rng.seed = 5418
	twin_rng.seed = 5418
	var gear := _item()
	gear["locked"] = true
	gear["bound"] = true
	var original := gear.duplicate(true)
	var result := WORKSHOP.preview(gear, "assault", 100, rng)
	var twin := WORKSHOP.preview(gear, "assault", 100, twin_rng)
	_check(result["ok"] and result["cost"] == 12 and result["balance"] == 88, "first preview charges 12 crystals exactly once")
	_check(result["item"]["proposal"] == twin["item"]["proposal"], "seeded option rolls are deterministic")
	_check(gear == original and result["item"]["locked"] and result["item"]["bound"], "workshop permits protected and bound gear without mutating input or flags")
	var proposal_item: Dictionary = result["item"]
	_check(proposal_item["proposal"]["options"].size() == 2 and proposal_item["affixes"].is_empty(), "preview persists two alternatives without granting either")
	_same_failure(WORKSHOP.preview(proposal_item, "guard", 88, rng), proposal_item, 88, "pending proposal prevents duplicate charges or reroll")
	_same_failure(WORKSHOP.remove(proposal_item, 0, 88), proposal_item, 88, "pending choice blocks incompatible deletion")
	_same_failure(WORKSHOP.choose(proposal_item, -1), proposal_item, 0, "invalid choice leaves stored candidates unchanged")
	var candidate: Dictionary = proposal_item["proposal"]["options"][0].duplicate(true)
	result = WORKSHOP.choose(RULES.normalize(JSON.parse_string(JSON.stringify(proposal_item))), 0)
	_check(result["ok"] and result["item"]["affixes"] == [candidate] and result["item"]["proposal"].is_empty(), "reloaded proposal grants exactly the chosen affix")
	gear = result["item"]
	_same_failure(WORKSHOP.choose(gear, 0), gear, 0, "resolved proposal cannot be claimed twice")
	result = WORKSHOP.preview(gear, "assault", 88, rng)
	_check(result["ok"] and result["cost"] == 20 and result["balance"] == 68, "second affix cost increases to 20")
	_check(result["item"]["proposal"]["options"].size() == 1 and result["item"]["proposal"]["options"][0]["stat"] != candidate["stat"], "family with one unused stat offers one nonduplicate candidate")
	gear = WORKSHOP.choose(result["item"], 0)["item"]
	_same_failure(WORKSHOP.preview(gear, "assault", 68, rng), gear, 68, "fully owned family cannot waste currency")
	result = WORKSHOP.preview(gear, "guard", 68, rng)
	_check(result["ok"] and result["cost"] == 28 and result["balance"] == 40, "third affix costs 28")
	gear = WORKSHOP.choose(result["item"], 1)["item"]
	_same_failure(WORKSHOP.preview(gear, "flow", 40, rng), gear, 40, "full legendary gear refuses fourth option")
	_same_failure(WORKSHOP.remove(gear, 0, 5), gear, 5, "insufficient removal currency does not destroy an option")
	_same_failure(WORKSHOP.remove(gear, 3, 40), gear, 40, "invalid removal index does not charge")
	for expected_focus in range(1, 4):
		result = WORKSHOP.remove(gear, 0, 100)
		_check(result["ok"] and result["balance"] == 94 and result["cost"] == 6 and result["item"]["focus"] == expected_focus, "removal pays 6 and builds focus %d" % expected_focus)
		gear = result["item"]
	result = WORKSHOP.preview(gear, "flow", 100, rng)
	_check(result["ok"] and result["item"]["focus"] == 0, "three focus points consumed once on next paid preview")
	for affix in result["item"]["proposal"]["options"]:
		_check(affix["value"] == RULES.STAT_RANGES[affix["stat"]].y, "focused candidate reaches its stat maximum")
	var abandoned := WORKSHOP.discard(result["item"])
	_check(abandoned["ok"] and abandoned["item"]["proposal"].is_empty() and abandoned["item"]["focus"] == 0 and not abandoned.has("balance"), "discard removes candidates without refund or restoring spent focus")
	gear = _item("일반")
	_same_failure(WORKSHOP.preview(gear, "guard", 11, rng), gear, 11, "insufficient preview currency leaves gear unchanged")
	_same_failure(WORKSHOP.preview(gear, "invalid", 100, rng), gear, 100, "unknown family refuses payment")
	_same_failure(WORKSHOP.preview(gear, "guard", 100, null), gear, 100, "missing RNG refuses payment")
	gear = WORKSHOP.choose(WORKSHOP.preview(gear, "guard", 100, rng)["item"], 0)["item"]
	_same_failure(WORKSHOP.preview(gear, "flow", 100, rng), gear, 100, "ordinary gear allows one option only")

func _test_trade_and_protection() -> void:
	var gear := _item()
	_check(RULES.tradable(gear) and not RULES.protected(gear), "fresh field gear may trade and follow ordinary salvage policy")
	gear["origin"] = "raid"
	_check(RULES.tradable(gear) and RULES.protected(gear), "fresh raid gear may trade but is protected from automatic salvage")
	for mutation in [{"locked": true}, {"bound": true}, {"trade_count": 1}, {"set": "초보자"}]:
		var changed := gear.duplicate(true)
		changed.merge(mutation, true)
		_check(not RULES.tradable(changed) and not RULES.trade_block_reason(changed).is_empty(), "trade restriction enforced: %s" % str(mutation))
	gear = _item()
	gear["affixes"] = [{"stat": "hp_pct", "value": 4}]
	_check(RULES.protected(gear) and RULES.tradable(gear), "crafted option protects gear without preventing its initial trade")
	var rng := RandomNumberGenerator.new()
	gear = WORKSHOP.preview(gear, "assault", 100, rng)["item"]
	_check(RULES.protected(gear) and not RULES.tradable(gear), "unresolved paid proposal is protected and cannot be traded")
	_check(not RULES.tradable({"slot": "invalid"}), "malformed gear cannot enter the market")

func _test_option_crystals() -> void:
	var gear := _item()
	gear["bound"] = true
	gear["locked"] = true
	gear["focus"] = 2
	gear["affixes"] = [{"stat": "attack_pct", "value": 6}, {"stat": "hp_pct", "value": 7}]
	var original := gear.duplicate(true)
	var extraction := WORKSHOP.extract(gear, 0, 50)
	_check(extraction["ok"] and extraction["cost"] == 18 and extraction["balance"] == 32, "extraction charges exactly 18 essence")
	_check(gear == original, "extraction leaves input item untouched until caller commits")
	var expected := original.duplicate(true)
	expected["affixes"].remove_at(0)
	_check(extraction["item"] == expected, "extraction removes just the selected option, retaining focus, lock, and metadata")
	var crystal: Dictionary = extraction["crystal"]
	_check(crystal["item_type"] == "option_crystal" and crystal["stored_option"] == original["affixes"][0], "extraction preserves exact option stat and value")
	_check(crystal["rarity"] == "전설" and RULES.quality_text(crystal) == "최상급", "maximum roll crystal has legendary rarity and highest quality")
	_check(not crystal["bound"] and crystal["trade_count"] == 0 and RULES.tradable(crystal), "self-equipped gear's original crafted option can be extracted for sale")
	_check(crystal["origin"] == gear["origin"] and crystal["source_id"] == gear["source_id"] and crystal["zone"] == gear["zone"], "crystal preserves the equipment's source history")
	_check(crystal["id"] != gear["id"] and RULES.protected(crystal), "crystal gets its own identifier and automatic salvage protection")
	_check(crystal["slot"] == "accessory" and crystal["level"] == 1 and crystal["power"] == 0 and crystal["affixes"].is_empty() and crystal["proposal"].is_empty() and RULES.option_capacity(crystal) == 0, "crystal cannot masquerade as usable equipment")
	_check(RULES.affix_text(crystal) == "공격력 +6%" and RULES.origin_text(crystal) == "옵션 결정", "crystal display clearly exposes the retained option")
	_check(RULES.affix_profile([crystal]) == {"attack_pct": 0, "hp_pct": 0, "defense": 0, "haste_pct": 0, "ultimate_pct": 0}, "loose crystals do not grant equipped stats")
	_check(RULES.normalize(JSON.parse_string(JSON.stringify(crystal))) == crystal, "option crystal survives JSON save/load unchanged")
	_check(RULES.normalize({"item_type": "option_crystal", "stored_option": {"stat": "attack_pct", "value": NAN}}).is_empty(), "nonfinite crystal option rejected")
	_check(RULES.normalize({"item_type": "option_crystal", "stored_option": []}).is_empty(), "malformed crystal option container rejected")
	_check(RULES.normalize({"item_type": "other"}).is_empty(), "unknown item kind cannot default to tradable gear")
	var rng := RandomNumberGenerator.new()
	_same_failure(WORKSHOP.preview(crystal, "guard", 100, rng), crystal, 100, "crystal cannot generate additional options")
	_same_failure(WORKSHOP.remove(crystal, 0, 100), crystal, 100, "crystal cannot use equipment option deletion")
	_same_failure(WORKSHOP.extract(crystal, 0, 100), crystal, 100, "crystal cannot recursively extract itself")
	_same_failure(WORKSHOP.choose(crystal, 0), crystal, 0, "crystal cannot claim a fabricated workshop proposal")
	_same_failure(WORKSHOP.discard(crystal), crystal, 0, "crystal cannot discard an equipment proposal")
	_same_failure(WORKSHOP.extract(gear, 0, 17), gear, 17, "unaffordable extraction does not delete the original option")
	_same_failure(WORKSHOP.extract(gear, -1, 100), gear, 100, "negative extraction index does not charge")
	_same_failure(WORKSHOP.extract(gear, 2, 100), gear, 100, "past-end extraction index does not charge")
	var pending := WORKSHOP.preview(gear, "flow", 100, rng)["item"] as Dictionary
	_same_failure(WORKSHOP.extract(pending, 0, 100), pending, 100, "unresolved proposal blocks extraction")
	var once := _item()
	once["affixes"] = [{"stat": "defense", "value": 3}]
	var extracted := WORKSHOP.extract(once, 0, 100)
	_check(extracted["crystal"]["rarity"] == "희귀", "nonmaximum option keeps rare crystal quality")
	_same_failure(WORKSHOP.extract(extracted["item"], 0, 82), extracted["item"], 82, "updated source cannot duplicate a removed option")
	var target := _item()
	target["id"] = "destination"
	target["bound"] = true
	target["locked"] = true
	target["focus"] = 3
	var target_original := target.duplicate(true)
	var crystal_original := crystal.duplicate(true)
	var applied := WORKSHOP.apply_crystal(target, crystal, 50)
	_check(applied["ok"] and applied["cost"] == 8 and applied["balance"] == 42, "applying a crystal charges exactly 8 essence")
	_check(target == target_original and crystal == crystal_original, "crystal application mutates neither source argument")
	expected = target.duplicate(true)
	expected["affixes"].append(crystal["stored_option"].duplicate(true))
	_check(applied["item"] == expected, "application preserves exact rolled value and destination metadata/focus")
	_same_failure(WORKSHOP.apply_crystal(applied["item"], crystal, 42), applied["item"], 42, "same-stat application cannot duplicate an option")
	_same_failure(WORKSHOP.apply_crystal(target, crystal, 7), target, 7, "unaffordable application does not grant the option")
	_same_failure(WORKSHOP.apply_crystal(crystal, crystal, 100), crystal, 100, "crystal cannot receive another crystal")
	_same_failure(WORKSHOP.apply_crystal(target, gear, 100), target, 100, "ordinary gear cannot serve as a crystal")
	var locked_crystal := crystal.duplicate(true)
	locked_crystal["locked"] = true
	_same_failure(WORKSHOP.apply_crystal(target, locked_crystal, 100), target, 100, "locked crystal cannot be consumed")
	_same_failure(WORKSHOP.apply_crystal(pending, crystal, 100), pending, 100, "pending destination cannot receive a crystal")
	var full := _item("일반")
	full["affixes"] = [{"stat": "defense", "value": 2}]
	_same_failure(WORKSHOP.apply_crystal(full, crystal, 100), full, 100, "full equipment cannot receive a crystal")
	for stat in RULES.STAT_RANGES:
		var bounds: Vector2i = RULES.STAT_RANGES[stat]
		_check(RULES.option_quality_text({"stat": stat, "value": bounds.y}) == "최상급" and RULES.option_quality_text({"stat": stat, "value": bounds.x}) == "기본", "quality uses each stat's own roll range: %s" % stat)
		for value in range(bounds.x, bounds.y + 1):
			var specimen := _item()
			specimen["affixes"] = [{"stat": stat, "value": value}]
			var result := WORKSHOP.extract(specimen, 0, 100)
			var restored := WORKSHOP.apply_crystal(result["item"], result["crystal"], result["balance"])
			_check(restored["ok"] and restored["item"]["affixes"] == specimen["affixes"] and restored["balance"] == 74, "every valid roll survives paid extraction/application without reroll: %s=%d" % [stat, value])

func _test_option_trade_lineage() -> void:
	for inherited_from_item in [false, true]:
		var original := _item()
		original["affixes"] = [{"stat": "haste_pct", "value": 3}]
		if inherited_from_item:
			original["trade_count"] = 1
			original["bound"] = true
		else:
			original["affixes"][0]["trade_count"] = 1
		_check(not RULES.tradable(original), "traded item or traded embedded option blocks listing")
		var extraction := WORKSHOP.extract(original, 0, 100)
		var crystal: Dictionary = extraction["crystal"]
		_check(extraction["ok"] and crystal["trade_count"] == 1 and crystal["bound"] and crystal["stored_option"].get("trade_count", 0) == 1 and not RULES.tradable(crystal), "extraction preserves purchased option's once-only trade history")
		var loaded := RULES.normalize(JSON.parse_string(JSON.stringify(crystal)))
		_check(loaded == crystal, "trade lineage survives crystal save/load")
		loaded["bound"] = false
		loaded["trade_count"] = 0
		_check(not RULES.tradable(loaded), "removing crystal wrapper flags does not erase stored option trade history")
		var destination := _item()
		destination["id"] = "new_destination"
		var applied := WORKSHOP.apply_crystal(destination, crystal, 100)
		_check(applied["ok"] and applied["item"]["affixes"][0].get("trade_count", 0) == 1 and not RULES.tradable(applied["item"]), "transplanted purchased option keeps new equipment from being resold")
		var again := WORKSHOP.extract(applied["item"], 0, 92)
		_check(again["ok"] and again["crystal"]["bound"] and not RULES.tradable(again["crystal"]), "repeated transplant/extract cannot launder purchased option history")
		_check(again["crystal"]["stored_option"]["value"] == 3, "trade lineage never rerolls the option value")
	var regular := _item()
	regular["affixes"] = [{"stat": "hp_pct", "value": 8, "trade_count": 0}]
	_check(RULES.normalize(regular)["affixes"] == [{"stat": "hp_pct", "value": 8}], "zero trade history omitted for backward-compatible option dictionaries")

func _run() -> void:
	_test_normalization()
	_test_generation_and_sets()
	_test_workshop()
	_test_trade_and_protection()
	_test_option_crystals()
	_test_option_trade_lineage()
	print("v54_equipment_rules_smoke_test_%s checks=%d failures=%d" % ["ok" if failures.is_empty() else "failed", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
